import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecowell/features/visit/domain/visit_models.dart';
import 'package:ecowell/features/visit/presentation/visit_result_view.dart';
import 'package:ecowell/shared/widgets/offline_strip.dart';

void main() {
  testWidgets('offline strip explains that saved content is shown',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OfflineStrip())),
    );
    expect(find.text('You are offline. Showing saved content.'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
  });

  testWidgets('visit result says it will sync when back online',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VisitResultView(
          result: const VisitResult(
            preScore: 10,
            postScore: 7,
            stressReductionScore: 3,
            streakCount: 2,
            longestStreak: 5,
          ),
          pendingSync: true,
          onDone: () {},
        ),
      ),
    ));
    expect(find.textContaining('Saved on this phone'), findsOneWidget);
  });
}
