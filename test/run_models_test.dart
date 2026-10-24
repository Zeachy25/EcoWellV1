import 'package:flutter_test/flutter_test.dart';

import 'package:ecowell/core/utils/format.dart';
import 'package:ecowell/features/runs/domain/run_models.dart';

void main() {
  group('paceSecondsPerKm', () {
    test('turns distance and time into seconds per kilometre', () {
      expect(paceSecondsPerKm(1000, 300), 300); // 5:00 /km
      expect(paceSecondsPerKm(2000, 720), 360); // 6:00 /km
    });

    test('is null until there is real movement', () {
      expect(paceSecondsPerKm(0, 300), isNull);
      expect(paceSecondsPerKm(9, 300), isNull);
      expect(paceSecondsPerKm(1000, 0), isNull);
    });
  });

  group('newRunId', () {
    test('looks like a UUID v4 (Supabase accepts it as the primary key)',
        () {
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(newRunId(), matches(pattern));
      expect(newRunId(), isNot(equals(newRunId())));
    });
  });

  group('RunPoint', () {
    test('survives the [lat, lng, epochSeconds] round trip', () {
      final original = RunPoint(
        lat: 14.5995,
        lng: 120.9842,
        time: DateTime(2026, 10, 20, 6, 30),
      );

      final restored = RunPoint.fromJson(original.toJson().cast<dynamic>());

      expect(restored.lat, original.lat);
      expect(restored.lng, original.lng);
      expect(
        restored.time.millisecondsSinceEpoch ~/ 1000,
        original.time.millisecondsSinceEpoch ~/ 1000,
      );
    });
  });

  group('RunRecord storage', () {
    final started = DateTime(2026, 10, 20, 6, 30);
    final ended = started.add(const Duration(minutes: 15));

    RunRecord record({RunStatus status = RunStatus.pendingSync}) {
      return RunRecord(
        id: '0f1e2d3c-4b5a-4697-8899-aabbccddeeff',
        userId: 'user-1',
        type: RunActivityType.run,
        startedAt: started,
        endedAt: ended,
        distanceMeters: 2000,
        durationSeconds: 720,
        path: [
          RunPoint(lat: 14.6, lng: 121.0, time: started),
          RunPoint(lat: 14.61, lng: 121.01, time: ended),
        ],
        status: status,
      );
    }

    test('computes average pace from the stored numbers', () {
      expect(record().avgPaceSecondsPerKm, 360); // 2 km in 12 min
    });

    test('round-trips through the local SQLite row shape', () {
      final row = <String, Object?>{
        'id': record().id,
        'user_id': record().userId,
        'activity_type': 'run',
        'started_at': started.toUtc().millisecondsSinceEpoch,
        'ended_at': ended.toUtc().millisecondsSinceEpoch,
        'distance_m': 2000.0,
        'duration_s': 720,
        // The store writes the path as a JSON string.
        'path': '[[14.6,121.0,${started.millisecondsSinceEpoch ~/ 1000}],'
            '[14.61,121.01,${ended.millisecondsSinceEpoch ~/ 1000}]]',
        'status': 'pendingSync',
        'updated_at': ended.millisecondsSinceEpoch,
      };

      final restored = RunRecord.fromRow(row);

      expect(restored, isNotNull);
      expect(restored!.id, record().id);
      expect(restored.type, RunActivityType.run);
      expect(restored.distanceMeters, 2000);
      expect(restored.durationSeconds, 720);
      expect(restored.avgPaceSecondsPerKm, 360);
      expect(restored.path, hasLength(2));
      expect(restored.status, RunStatus.pendingSync);
    });

    test('rejects an active checkpoint row but keeps finished ones', () {
      final activeRow = <String, Object?>{
        'id': record().id,
        'user_id': record().userId,
        'activity_type': 'walk',
        'started_at': started.toUtc().millisecondsSinceEpoch,
        'ended_at': ended.toUtc().millisecondsSinceEpoch,
        'distance_m': 100.0,
        'duration_s': 60,
        'path': '[]',
        'status': 'active',
        'updated_at': ended.millisecondsSinceEpoch,
      };

      final restored = RunRecord.fromRow(activeRow);
      expect(restored!.status, RunStatus.active);
      expect(restored.path, isEmpty);

      final badRow = {...activeRow, 'activity_type': 'cycling'};
      expect(RunRecord.fromRow(badRow), isNull);
    });

    test('toInsertJson sends the client id, pace and polyline', () {
      final json = record().toInsertJson();

      expect(json['id'], record().id);
      expect(json['user_id'], 'user-1');
      expect(json['activity_type'], 'run');
      expect(json['duration_s'], 720);
      expect(json['avg_pace_s_per_km'], 360);
      expect(json['path'], isA<List<dynamic>>());
      expect((json['path'] as List).first, hasLength(3));
    });
  });

  group('RunState', () {
    test('is only tracking while recording or paused', () {
      const idle = RunState();
      expect(idle.isTracking, isFalse);

      const recording =
          RunState(phase: RunPhase.recording, distanceMeters: 100);
      expect(recording.isTracking, isTrue);
      expect(recording.avgPaceSecondsPerKm, isNull);

      const finished = RunState(phase: RunPhase.finished);
      expect(finished.isTracking, isFalse);
    });
  });

  group('run formatters', () {
    test('formatPace renders minutes and seconds', () {
      expect(formatPace(342), '5:42');
      expect(formatPace(65), '1:05');
      expect(formatPace(null), '-');
    });

    test('formatTimer grows into hours', () {
      expect(formatTimer(65), '01:05');
      expect(formatTimer(3661), '1:01:01');
    });
  });
}
