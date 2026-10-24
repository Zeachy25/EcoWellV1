import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// What the user is recording: a walk or a run.
enum RunActivityType {
  walk,
  run;

  String get label => this == RunActivityType.run ? 'Run' : 'Walk';

  IconData get icon => this == RunActivityType.run
      ? Icons.directions_run
      : Icons.directions_walk;

  String get wire => name;
}

/// Where the recorder is in its life cycle.
enum RunPhase {
  /// Nothing recorded yet.
  idle,

  /// GPS is being tracked and the timer is running.
  recording,

  /// Paused: the timer and the path are frozen.
  paused,

  /// Stopped; the finished run is waiting to be saved or discarded.
  finished,
}

/// Whether a saved run has reached the server yet.
enum RunStatus {
  /// Still being recorded (checkpoint only, never shown in history).
  active,

  /// Finished on the phone, waiting for the network.
  pendingSync,

  /// The server has it; the local row is kept as the offline history.
  synced,
}

/// One recorded GPS sample.
class RunPoint {
  const RunPoint({
    required this.lat,
    required this.lng,
    required this.time,
  });

  final double lat;
  final double lng;
  final DateTime time;

  LatLng get latLng => LatLng(lat, lng);

  /// Stored and uploaded as `[lat, lng, epochSeconds]`.
  List<num> toJson() => [
        lat,
        lng,
        time.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond,
      ];

  static RunPoint fromJson(List<dynamic> raw) {
    return RunPoint(
      lat: (raw[0] as num).toDouble(),
      lng: (raw[1] as num).toDouble(),
      time: DateTime.fromMillisecondsSinceEpoch(
        (raw[2] as num).toInt() * Duration.millisecondsPerSecond,
        isUtc: true,
      ).toLocal(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RunPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// Average pace in seconds per kilometre, or null when there is not
/// enough movement to say anything useful.
int? paceSecondsPerKm(double distanceMeters, int durationSeconds) {
  if (distanceMeters < 10 || durationSeconds <= 0) return null;
  return (durationSeconds / (distanceMeters / 1000)).round();
}

/// A fresh client-side id for a run: a proper UUID v4, so Supabase
/// accepts it as the primary key. The same id is written on the phone and
/// sent with the insert, so retrying a failed upload never creates a
/// duplicate row.
String newRunId() {
  final rand = Random.secure();
  String hex(int digits) {
    var s = '';
    while (s.length < digits) {
      s += rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    }
    return s.substring(0, digits);
  }

  const variants = '89ab';
  return '${hex(8)}-${hex(4)}-4${hex(3)}-'
      '${variants[rand.nextInt(variants.length)]}${hex(3)}-${hex(12)}';
}

/// Live state of an active Quick Run. The recorder publishes a fresh copy
/// whenever anything changes; the record screen renders it as it comes.
class RunState {
  const RunState({
    this.phase = RunPhase.idle,
    this.type = RunActivityType.walk,
    this.startedAt,
    this.elapsedSeconds = 0,
    this.movingSeconds = 0,
    this.distanceMeters = 0,
    this.path = const [],
    this.lastPosition,
  });

  final RunPhase phase;
  final RunActivityType type;

  /// Original start time (before any pause, resume or app restart).
  final DateTime? startedAt;

  /// Timer seconds, excluding paused time.
  final int elapsedSeconds;

  /// Portion of [elapsedSeconds] spent actually moving.
  final int movingSeconds;

  final double distanceMeters;
  final List<RunPoint> path;

  /// Most recent GPS reading, for the camera and the blue dot.
  final LatLng? lastPosition;

  bool get isTracking =>
      phase == RunPhase.recording || phase == RunPhase.paused;

  int? get avgPaceSecondsPerKm =>
      paceSecondsPerKm(distanceMeters, elapsedSeconds);
}

/// A finished (or checkpointed) run as stored on the phone and uploaded
/// to Supabase.
class RunRecord {
  const RunRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.path,
    this.status = RunStatus.pendingSync,
  });

  final String id;
  final String userId;
  final RunActivityType type;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;

  /// Active timer seconds (excludes pauses).
  final int durationSeconds;

  final List<RunPoint> path;
  final RunStatus status;

  int? get avgPaceSecondsPerKm =>
      paceSecondsPerKm(distanceMeters, durationSeconds);

  RunRecord copyWith({
    String? userId,
    double? distanceMeters,
    int? durationSeconds,
    List<RunPoint>? path,
    RunStatus? status,
  }) {
    return RunRecord(
      id: id,
      userId: userId ?? this.userId,
      type: type,
      startedAt: startedAt,
      endedAt: endedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      path: path ?? this.path,
      status: status ?? this.status,
    );
  }

  /// The payload sent to Supabase (the `runs` table). The client-generated
  /// [id] is included so a retried upload is idempotent.
  Map<String, Object?> toInsertJson() => {
        'id': id,
        'user_id': userId,
        'activity_type': type.wire,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'distance_m': distanceMeters,
        'duration_s': durationSeconds,
        'avg_pace_s_per_km': avgPaceSecondsPerKm,
        'path': [for (final p in path) p.toJson()],
      };

  /// Reads a row written by `RunStore` (local SQLite). Accepts the path
  /// either as a JSON string or as an already-decoded list.
  static RunRecord? fromRow(Map<String, Object?> row) {
    final type = RunActivityType.values.asNameMap()[row['activity_type']];
    final started = row['started_at'];
    final ended = row['ended_at'];
    if (type == null || started is! int || ended is! int) return null;

    Object? rawPath = row['path'];
    if (rawPath is String) {
      rawPath = rawPath.isEmpty
          ? const <dynamic>[]
          : jsonDecode(rawPath) as dynamic;
    }
    final points = <RunPoint>[];
    if (rawPath is List) {
      for (final item in rawPath) {
        if (item is List && item.length >= 3) {
          points.add(RunPoint.fromJson(item));
        }
      }
    }

    return RunRecord(
      id: row['id'] as String,
      userId: row['user_id'] as String? ?? '',
      type: type,
      startedAt:
          DateTime.fromMillisecondsSinceEpoch(started, isUtc: true).toLocal(),
      endedAt:
          DateTime.fromMillisecondsSinceEpoch(ended, isUtc: true).toLocal(),
      distanceMeters: (row['distance_m'] as num?)?.toDouble() ?? 0,
      durationSeconds: (row['duration_s'] as num?)?.toInt() ?? 0,
      path: points,
      status: RunStatus.values.asNameMap()[row['status'] as String?] ??
          RunStatus.pendingSync,
    );
  }
}
