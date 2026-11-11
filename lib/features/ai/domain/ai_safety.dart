import 'dart:math';

import 'ai_message.dart';

/// Shared safety copy and local fallback replies for the AI coach.
///
/// Crisis detection is intentionally simple and duplicated in the Edge
/// Function. The server path is the source of truth; this local copy keeps the
/// chat useful when the phone is offline.
abstract final class AiSafety {
  static const disclaimer =
      'EcoWell is a wellness tool, not a replacement for professional mental '
      'health care. If you are in crisis or need urgent help, contact your '
      'local emergency services or a crisis hotline.';

  static const crisisReply =
      "I'm really sorry you're carrying this right now. You deserve support, "
      "and you don't have to face it alone.\n\n"
      'Please reach out now:\n'
      '• National Center for Mental Health (NCMH) Crisis Hotline: '
      '1553 (nationwide, 24/7)\n'
      '• NCMH mobile: 0917-899-8727 or 0966-351-4518\n'
      '• Emergency: 911\n\n'
      'If you are in immediate danger, please call 911 or go to the nearest '
      'emergency room. If you can, stay with someone you trust while you '
      'make contact.';

  static const crisisResources = <CrisisResource>[
    CrisisResource('NCMH Crisis Hotline', '1553'),
    CrisisResource('NCMH mobile', '09178998727'),
    CrisisResource('NCMH mobile', '09663514518'),
    CrisisResource('Emergency', '911'),
  ];

  static final List<RegExp> _crisisPatterns = [
    RegExp(r'suicid', caseSensitive: false),
    RegExp(r'kill(ing)? myself', caseSensitive: false),
    RegExp(r'end(ing)? my life', caseSensitive: false),
    RegExp(r'self[-\s]?harm', caseSensitive: false),
    RegExp(r'hurt(ing)? myself', caseSensitive: false),
    RegExp(r"don'?t want to (live|be alive)", caseSensitive: false),
    RegExp(r'better off dead', caseSensitive: false),
    RegExp(r'no reason to live', caseSensitive: false),
    RegExp(r'magpakamatay', caseSensitive: false),
    RegExp(r'patayin (ang )?sarili', caseSensitive: false),
    RegExp(r'saktan (ang )?sarili', caseSensitive: false),
    RegExp(r'(ayoko|ayaw ko) nang mabuhay', caseSensitive: false),
  ];

  static bool isCrisis(String text) {
    return _crisisPatterns.any((pattern) => pattern.hasMatch(text));
  }

  static _FallbackKind _fallbackKind(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'stress|anxi|worry|overwhelm|panic').hasMatch(lower)) {
      return _FallbackKind.breathing;
    }
    if (RegExp(r'sad|down|low|alone|lonely|tired').hasMatch(lower)) {
      return _FallbackKind.grounding;
    }
    if (RegExp(r'park|walk|outside|nature|green|place').hasMatch(lower)) {
      return _FallbackKind.nature;
    }
    return _FallbackKind.general;
  }

  /// The guided exercise offered by an offline fallback, if any.
  static AiAction? fallbackAction(String text) {
    return switch (_fallbackKind(text)) {
      _FallbackKind.breathing => AiAction.breathing,
      _FallbackKind.grounding => AiAction.grounding,
      _FallbackKind.nature || _FallbackKind.general => null,
    };
  }

  /// A short, supportive answer used when the server or network is down.
  /// It never pretends to be the AI model.
  static String fallbackReply(String text) {
    return switch (_fallbackKind(text)) {
      _FallbackKind.breathing =>
        'I can’t reach the AI coach right now. If it would help, you can start '
            'the Breathing Exercise in EcoWell.',
      _FallbackKind.grounding =>
        'I can’t reach the AI coach right now. If you feel up to it, you can '
            'start the grounding exercise in EcoWell.',
      _FallbackKind.nature =>
        'I can’t reach the AI coach right now. A walk in a nearby green space '
            'may help; open the Map tab to find a place.',
      _FallbackKind.general =>
        'I can’t reach the AI coach right now. Try a small reset by relaxing '
            'your jaw and shoulders and taking a few slow breaths.',
    };
  }

  static List<String> activityFollowUpOptions(
    AiAction action, {
    required bool completed,
  }) {
    if (completed) {
      return switch (action) {
        AiAction.breathing => const [
          'Nice work making time for that. How do you feel now?',
          'You made space for a calming moment. What are you noticing now?',
          'Well done. Did anything shift for you during the breathing exercise?',
        ],
        AiAction.grounding => const [
          'Nice work completing that. How do you feel in this moment?',
          'You took a moment to reconnect with what is around you. How was it?',
          'Well done. What did you notice during the grounding exercise?',
        ],
      };
    }

    return switch (action) {
      AiAction.breathing => const [
        'That’s okay—you can stop whenever you need to. How are you feeling?',
        'No problem; you can return to it anytime. How are you doing now?',
        'It’s okay to pause. Would you like to talk about how it felt?',
      ],
      AiAction.grounding => const [
        'That’s okay—you can stop whenever you need to. How are you feeling?',
        'No problem; you can return to it anytime. What would feel helpful now?',
        'It’s okay to pause. Would you like to talk about how it felt?',
      ],
    };
  }

  static String activityFollowUp(
    AiAction action, {
    required bool completed,
    Random? random,
  }) {
    final options = activityFollowUpOptions(action, completed: completed);
    return options[(random ?? Random()).nextInt(options.length)];
  }
}

enum _FallbackKind { breathing, grounding, nature, general }

class CrisisResource {
  const CrisisResource(this.label, this.phone);

  final String label;
  final String phone;
}
