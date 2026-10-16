import 'package:flutter/material.dart';

import '../domain/visit_models.dart';

class VisitResultView extends StatelessWidget {
  const VisitResultView({
    super.key,
    required this.result,
    required this.onDone,
  });

  final VisitResult result;
  final VoidCallback onDone;

  String get _message {
    final r = result.stressReductionScore;
    if (r > 0) {
      return 'Your stress score dropped by $r ${r == 1 ? 'point' : 'points'}. '
          'Nice work taking time for yourself.';
    }
    if (r == 0) {
      return 'No change this time. Staying a little longer outdoors, or '
          'trying a breathing exercise, may help.';
    }
    return 'Your score went up by ${-r} ${r == -1 ? 'point' : 'points'}. '
        'That can happen. Be gentle with yourself.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.celebration, size: 64, color: scheme.primary),
          const SizedBox(height: 12),
          Text('Visit complete',
              style: textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Stress Reduction Score', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    result.stressReductionScore > 0
                        ? '+${result.stressReductionScore}'
                        : '${result.stressReductionScore}',
                    style: textTheme.displayMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _ScoreTile(label: 'Before', value: result.preScore)),
              const SizedBox(width: 12),
              Expanded(child: _ScoreTile(label: 'After', value: result.postScore)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Stress scores range from 0 to 16. Lower means calmer.',
              style: textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.local_fire_department, color: scheme.primary),
            title: Text('Streak: ${result.streakCount} '
                '${result.streakCount == 1 ? 'day' : 'days'}'),
            subtitle: Text('Longest: ${result.longestStreak} '
                '${result.longestStreak == 1 ? 'day' : 'days'}'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onDone, child: const Text('Done')),
          const SizedBox(height: 8),
          Text(
            'EcoWell is a wellness tool, not a medical assessment.',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(label, style: textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('$value',
                style: textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
