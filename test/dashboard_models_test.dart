import 'package:flutter_test/flutter_test.dart';

import 'package:ecowell/features/dashboard/domain/dashboard_models.dart';

void main() {
  group('DashboardData', () {
    test('a brand-new user gets zeros, not an error', () {
      // What get_dashboard() returns before the first finished visit.
      final data = DashboardData.fromJson(const {
        'streak_count': 0,
        'longest_streak': 0,
        'total_visits': 0,
        'distinct_places': 0,
        'avg_reduction': null,
        'best_reduction': null,
        'total_minutes': 0,
        'activities_done': 0,
        'recent': <dynamic>[],
      });

      expect(data.streakCount, 0);
      expect(data.totalVisits, 0);
      expect(data.distinctPlaces, 0);
      expect(data.avgReduction, isNull);
      expect(data.bestReduction, isNull);
      expect(data.totalMinutes, 0);
      expect(data.activitiesDone, 0);
      expect(data.recent, isEmpty);
    });

    test('missing keys fall back to zero as well', () {
      final data = DashboardData.fromJson(const {});

      expect(data.totalVisits, 0);
      expect(data.recent, isEmpty);
    });

    test('reads finished visits', () {
      final data = DashboardData.fromJson(const {
        'total_visits': 1,
        'avg_reduction': 3.5,
        'best_reduction': 4,
        'recent': [
          {
            'place_name': 'Test Park',
            'entry_time': '2026-10-18T02:00:00Z',
            'exit_time': '2026-10-18T02:40:00Z',
            'pre_score': 12,
            'post_score': 8,
            'stress_reduction_score': 4,
          },
        ],
      });

      expect(data.totalVisits, 1);
      expect(data.avgReduction, 3.5);
      expect(data.bestReduction, 4);
      expect(data.recent.single.placeName, 'Test Park');
      expect(data.recent.single.reduction, 4);
      expect(data.recent.single.duration, const Duration(minutes: 40));
    });
  });
}
