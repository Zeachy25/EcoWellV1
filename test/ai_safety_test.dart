import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

import 'package:ecowell/features/ai/domain/ai_message.dart';
import 'package:ecowell/features/ai/domain/ai_safety.dart';

void main() {
  group('crisis detection', () {
    test('matches English and Filipino crisis phrases', () {
      expect(AiSafety.isCrisis('I am thinking about suicide'), isTrue);
      expect(AiSafety.isCrisis('I want to kill myself'), isTrue);
      expect(AiSafety.isCrisis('I keep self-harming'), isTrue);
      expect(AiSafety.isCrisis('I have no reason to live'), isTrue);
      expect(AiSafety.isCrisis('Gusto kong magpakamatay'), isTrue);
      expect(AiSafety.isCrisis('Ayoko nang mabuhay'), isTrue);
      expect(AiSafety.isCrisis('Ayaw ko nang mabuhay'), isTrue);
      expect(AiSafety.isCrisis('saktan ang sarili ko'), isTrue);
    });

    test('does not flag ordinary distress', () {
      expect(AiSafety.isCrisis('I am stressed about school'), isFalse);
      expect(AiSafety.isCrisis('I feel lonely today'), isFalse);
      expect(AiSafety.isCrisis('I need a break'), isFalse);
    });
  });

  group('local fallback replies', () {
    test('suggests breathing for stress keywords', () {
      final reply = AiSafety.fallbackReply('I feel so stressed');
      expect(reply, contains('Breathing Exercise'));
      expect(AiSafety.fallbackAction('I feel so stressed'), AiAction.breathing);
      expect(reply.split(' ').length, lessThanOrEqualTo(20));
    });

    group('activity follow-ups', () {
      test('offers varied follow-ups for each exercise outcome', () {
        for (final action in AiAction.values) {
          for (final completed in [true, false]) {
            final options = AiSafety.activityFollowUpOptions(
              action,
              completed: completed,
            );
            expect(options.length, greaterThan(1));
            expect(options.toSet().length, options.length);
            expect(
              AiSafety.activityFollowUp(
                action,
                completed: completed,
                random: Random(4),
              ),
              isIn(options),
            );
          }
        }
      });

      test('completed and early-exit follow-ups have distinct wording', () {
        final completed = AiSafety.activityFollowUpOptions(
          AiAction.breathing,
          completed: true,
        );
        final exitedEarly = AiSafety.activityFollowUpOptions(
          AiAction.breathing,
          completed: false,
        );

        expect(completed.toSet().intersection(exitedEarly.toSet()), isEmpty);
      });
    });

    test('suggests grounding for low mood keywords', () {
      final reply = AiSafety.fallbackReply('I feel lonely and tired');
      expect(reply, contains('grounding'));
      expect(
        AiSafety.fallbackAction('I feel lonely and tired'),
        AiAction.grounding,
      );
    });

    test('suggests a green space for nature keywords', () {
      final reply = AiSafety.fallbackReply('Where can I take a walk outside?');
      expect(reply, contains('green space'));
    });

    test('always offers a small reset', () {
      final reply = AiSafety.fallbackReply('Tell me a joke');
      expect(reply, contains('few slow breaths'));
      expect(AiSafety.fallbackAction('Tell me a joke'), isNull);
      expect(reply, isNot(contains('exercise')));
    });
  });

  test('crisis resources include national and emergency numbers', () {
    final phones = AiSafety.crisisResources.map((item) => item.phone).toSet();
    expect(phones, contains('1553'));
    expect(phones, contains('911'));
    expect(AiSafety.crisisReply, contains('1553'));
    expect(AiSafety.crisisReply, contains('911'));
  });
}
