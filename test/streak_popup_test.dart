import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecowell/features/dashboard/data/dashboard_repository.dart';
import 'package:ecowell/features/dashboard/domain/dashboard_models.dart';
import 'package:ecowell/features/visit/presentation/streak_popup.dart';

/// Minimal dashboard data: no extra visits, so only "today" lights up.
final _emptyDashboard = DashboardData.fromJson(const {
  'streak_count': 1,
  'longest_streak': 1,
  'total_visits': 1,
  'distinct_places': 1,
  'recent': <dynamic>[],
});

Widget _host(int streak) {
  return ProviderScope(
    overrides: [
      dashboardProvider.overrideWith((ref) async => _emptyDashboard),
    ],
    child: MaterialApp(home: StreakPopup(streakCount: streak)),
  );
}

void main() {
  testWidgets('shows the streak count and day unit', (tester) async {
    await tester.pumpWidget(_host(1));
    // The flame loops forever, so pump a fixed frame instead of settling.
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('1'), findsOneWidget);
    expect(find.text('DAY'), findsOneWidget);
    expect(find.text('Nice work!'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
  });

  testWidgets('a full week switches the unit to WEEK', (tester) async {
    await tester.pumpWidget(_host(7));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('7'), findsOneWidget);
    expect(find.text('WEEK'), findsOneWidget);
  });
}
