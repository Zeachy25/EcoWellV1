import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/location_service.dart';
import '../domain/run_models.dart';
import 'run_repository.dart';

/// Records a Quick Run: listens to GPS fixes, keeps the polyline, the
/// distance and the timers, and checkpoints the run to SQLite while it is
/// going so nothing is lost if the phone kills the app.
///
/// It shares geolocator's single position stream with the geofence watcher.
/// When the geofence is already running (the normal case) its foreground
/// service keeps the updates flowing with the screen off; when this
/// recorder is first, its own foreground-notification config does.
class RunRecorder {
  RunRecorder({
    required Future<void> Function(RunRecord record) onCheckpoint,
    required Future<void> Function(String id) onDiscarded,
  })  : _onCheckpoint = onCheckpoint,
        _onDiscarded = onDiscarded;

  final Future<void> Function(RunRecord record) _onCheckpoint;
  final Future<void> Function(String id) _onDiscarded;

  /// Ignore GPS readings worse than this (metres).
  static const maxAccuracy = 30.0;

  /// Ignore movement smaller than this between fixes (metres) so GPS jitter
  /// does not invent distance while the user stands still.
  static const minPointDistance = 5.0;

  /// A fix counts as "moving" for this long after it showed movement.
  static const movingGrace = Duration(seconds: 12);

  final ValueNotifier<RunState> state = ValueNotifier<RunState>(
    const RunState(),
  );

  StreamSubscription<Position>? _sub;
  Timer? _ticker;
  Timer? _checkpointTimer;

  final List<RunPoint> _points = [];
  DateTime? _lastMovementAt;

  /// Points to the checkpoint row so `finish` / `discard` can update it.
  String? _activeId;

  // ---- lifecycle ---------------------------------------------------------

  /// Starts recording. Returns false when location is off or not allowed.
  Future<bool> start(RunActivityType type) async {
    if (state.value.phase == RunPhase.recording) return true;
    if (!await LocationService.ensurePermission()) return false;

    _reset();
    _activeId = newRunId();
    state.value = RunState(
      phase: RunPhase.recording,
      type: type,
      startedAt: DateTime.now(),
    );
    _listen();
    await _checkpointNow();
    return true;
  }

  /// Continues a run that was checkpointed before the app was closed.
  Future<bool> resume(RunRecord record) async {
    if (state.value.isTracking) return false;
    if (!await LocationService.ensurePermission()) return false;

    _reset();
    _activeId = record.id;
    _points
      ..clear()
      ..addAll(record.path);
    state.value = RunState(
      phase: RunPhase.recording,
      type: record.type,
      startedAt: record.startedAt,
      elapsedSeconds: record.durationSeconds,
      distanceMeters: record.distanceMeters,
      path: List<RunPoint>.unmodifiable(_points),
    );
    _listen();
    await _checkpointNow();
    return true;
  }

  void pause() {
    final s = state.value;
    if (s.phase != RunPhase.recording) return;
    state.value = RunState(
      phase: RunPhase.paused,
      type: s.type,
      startedAt: s.startedAt,
      elapsedSeconds: s.elapsedSeconds,
      movingSeconds: s.movingSeconds,
      distanceMeters: s.distanceMeters,
      path: s.path,
      lastPosition: s.lastPosition,
    );
    _ticker?.cancel();
    _ticker = null;
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
  }

  void resumePaused() {
    final s = state.value;
    if (s.phase != RunPhase.paused) return;
    state.value = RunState(
      phase: RunPhase.recording,
      type: s.type,
      startedAt: s.startedAt,
      elapsedSeconds: s.elapsedSeconds,
      movingSeconds: s.movingSeconds,
      distanceMeters: s.distanceMeters,
      path: s.path,
      lastPosition: s.lastPosition,
    );
    _startTimers();
  }

  /// Stops recording and returns the finished run (not yet saved).
  RunRecord finish() {
    final s = state.value;
    final now = DateTime.now();
    final record = RunRecord(
      id: _activeId ?? newRunId(),
      userId: '',
      type: s.type,
      startedAt: s.startedAt ?? now,
      endedAt: now,
      distanceMeters: s.distanceMeters,
      durationSeconds: s.elapsedSeconds,
      path: List<RunPoint>.of(_points),
    );
    _teardown();
    state.value = const RunState(phase: RunPhase.finished);
    return record;
  }

  /// Throws the run away, including its checkpoint row.
  Future<void> discard() async {
    final id = _activeId;
    _teardown();
    state.value = const RunState();
    if (id != null) await _onDiscarded(id);
    _activeId = null;
  }

  /// Back to the idle screen after the summary was saved or discarded.
  void reset() {
    if (state.value.phase == RunPhase.finished) {
      state.value = const RunState();
    }
  }

  void dispose() {
    _teardown();
    state.dispose();
  }

  // ---- GPS ---------------------------------------------------------------

  void _listen() {
    _sub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Quick Run in progress',
          notificationText: 'Recording your walk or run. Keep EcoWell '
              'open or minimize it — the run keeps going.',
          enableWakeLock: true,
        ),
      ),
    ).listen(
      _onPosition,
      onError: (Object e) => debugPrint('Run recorder position error: $e'),
    );
    _startTimers();
  }

  void _startTimers() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _checkpointTimer ??=
        Timer.periodic(const Duration(seconds: 30), (_) => _checkpointNow());
  }

  void _onPosition(Position p) {
    final s = state.value;
    if (!s.isTracking) return;
    if (!p.accuracy.isFinite || p.accuracy > maxAccuracy) return;

    final latLng = LatLng(p.latitude, p.longitude);

    // The map follows the user even while paused.
    if (s.phase == RunPhase.paused) {
      state.value = _copyWith(s, lastPosition: latLng);
      return;
    }

    final time = p.timestamp.toLocal();

    if (_points.isNotEmpty) {
      final last = _points.last;
      final moved = Geolocator.distanceBetween(
        last.lat,
        last.lng,
        p.latitude,
        p.longitude,
      );
      if (moved < minPointDistance) {
        _noteMovement(p, moved);
        return;
      }
    }

    _points.add(RunPoint(lat: p.latitude, lng: p.longitude, time: time));
    _lastMovementAt = time;
    state.value = _copyWith(
      s,
      distanceMeters: s.distanceMeters + _segmentLength(),
      path: List<RunPoint>.unmodifiable(_points),
      lastPosition: latLng,
    );
  }

  double _segmentLength() {
    if (_points.length < 2) return 0;
    final a = _points[_points.length - 2];
    final b = _points.last;
    return Geolocator.distanceBetween(a.lat, a.lng, b.lat, b.lng);
  }

  void _noteMovement(Position p, double moved) {
    // A stationary GPS drifts a few metres; real movement is either
    // reported by the sensor or keeps growing between fixes.
    final speedOk = p.speed > 0.7;
    final grew = moved >= minPointDistance * 0.8;
    if (speedOk || grew) _lastMovementAt = p.timestamp.toLocal();
  }

  void _onTick() {
    final s = state.value;
    if (s.phase != RunPhase.recording) return;
    final now = DateTime.now();
    final moving = _lastMovementAt != null &&
        now.difference(_lastMovementAt!) < movingGrace;
    state.value = _copyWith(
      s,
      elapsedSeconds: s.elapsedSeconds + 1,
      movingSeconds: s.movingSeconds + (moving ? 1 : 0),
    );
  }

  Future<void> _checkpointNow() async {
    final s = state.value;
    final id = _activeId;
    if (id == null || !s.isTracking || s.startedAt == null) return;
    await _onCheckpoint(RunRecord(
      id: id,
      userId: '',
      type: s.type,
      startedAt: s.startedAt!,
      endedAt: DateTime.now(),
      distanceMeters: s.distanceMeters,
      durationSeconds: s.elapsedSeconds,
      path: List<RunPoint>.of(_points),
    ));
  }

  void _teardown() {
    _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _ticker = null;
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
    _points.clear();
    _lastMovementAt = null;
  }

  void _reset() {
    _teardown();
    _activeId = null;
  }

  RunState _copyWith(RunState s, {
    int? elapsedSeconds,
    int? movingSeconds,
    double? distanceMeters,
    List<RunPoint>? path,
    LatLng? lastPosition,
  }) {
    return RunState(
      phase: s.phase,
      type: s.type,
      startedAt: s.startedAt,
      elapsedSeconds: elapsedSeconds ?? s.elapsedSeconds,
      movingSeconds: movingSeconds ?? s.movingSeconds,
      distanceMeters: distanceMeters ?? s.distanceMeters,
      path: path ?? s.path,
      lastPosition: lastPosition ?? s.lastPosition,
    );
  }
}

final runRecorderProvider = Provider<RunRecorder>((ref) {
  final repo = ref.watch(runRepositoryProvider);
  final recorder = RunRecorder(
    onCheckpoint: (record) => repo.saveCheckpoint(record),
    onDiscarded: (id) => repo.discardCheckpoint(id),
  );
  ref.onDispose(recorder.dispose);
  return recorder;
});
