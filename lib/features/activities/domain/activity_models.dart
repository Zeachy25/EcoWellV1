import 'dart:convert';

import '../../../core/utils/format.dart';

/// One part of a breathing pattern, e.g. "Breathe in" for 4 seconds.
class BreathPhase {
  const BreathPhase({required this.label, required this.seconds, this.to});

  final String label;
  final int seconds;

  /// Circle size at the end of this phase (0.5 small .. 1.0 big).
  /// null = keep the current size (a "hold").
  final double? to;

  factory BreathPhase.fromJson(Map<String, dynamic> j) => BreathPhase(
        label: (j['label'] as String?) ?? '',
        seconds: (j['seconds'] as num?)?.toInt() ?? 4,
        to: (j['to'] as num?)?.toDouble(),
      );
}

/// One step of an activity: a breathing pattern or a text prompt.
class ActivityStep {
  const ActivityStep({
    required this.kind,
    required this.title,
    this.text = '',
    this.phases = const [],
    this.rounds = 1,
  });

  /// "breathe" or "prompt"
  final String kind;
  final String title;
  final String text;
  final List<BreathPhase> phases;
  final int rounds;

  bool get isBreathing => kind == 'breathe';

  factory ActivityStep.fromJson(Map<String, dynamic> j) => ActivityStep(
        kind: (j['kind'] as String?) ?? 'prompt',
        title: (j['title'] as String?) ?? '',
        text: (j['text'] as String?) ?? '',
        phases: [
          for (final p in (j['phases'] as List<dynamic>? ?? const []))
            BreathPhase.fromJson(Map<String, dynamic>.from(p as Map)),
        ],
        rounds: (j['rounds'] as num?)?.toInt() ?? 1,
      );
}

class Activity {
  const Activity({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.durationSec,
    required this.steps,
  });

  final String id;

  /// "breathing", "grounding" or "quick_run"
  final String type;
  final String title;
  final String description;
  final int durationSec;
  final List<ActivityStep> steps;

  String get durationText => formatDuration(durationSec.toDouble());

  factory Activity.fromJson(Map<String, dynamic> j) {
    dynamic raw = j['steps'];
    if (raw is String) raw = jsonDecode(raw);
    return Activity(
      id: j['id'] as String,
      type: (j['type'] as String?) ?? 'breathing',
      title: (j['title'] as String?) ?? '',
      description: (j['description'] as String?) ?? '',
      durationSec: (j['duration_sec'] as num?)?.toInt() ?? 0,
      steps: [
        for (final s in (raw as List<dynamic>? ?? const []))
          ActivityStep.fromJson(Map<String, dynamic>.from(s as Map)),
      ],
    );
  }
}
