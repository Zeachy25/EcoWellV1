import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard/data/dashboard_repository.dart';
import '../../visit/data/visit_repository.dart';
import '../data/activity_repository.dart';
import '../domain/activity_models.dart';
import 'breathing_step_view.dart';
import 'prompt_step_view.dart';

/// Runs an activity: intro -> each step in turn -> finished.
/// When it ends, the completion is saved (and linked to your open visit,
/// if you have one).
class ActivityRunnerScreen extends ConsumerStatefulWidget {
  const ActivityRunnerScreen({super.key, required this.activity});

  final Activity activity;

  @override
  ConsumerState<ActivityRunnerScreen> createState() =>
      _ActivityRunnerScreenState();
}

class _ActivityRunnerScreenState extends ConsumerState<ActivityRunnerScreen> {
  /// -1 = intro screen, 0.. = step number
  int _index = -1;
  bool _done = false;

  Activity get _a => widget.activity;

  void _next() {
    if (_index + 1 >= _a.steps.length) {
      _finish();
    } else {
      setState(() => _index++);
    }
  }

  Future<void> _finish() async {
    if (_done) return;
    setState(() => _done = true);
    try {
      final active = await ref.read(visitRepositoryProvider).fetchActiveVisit();
      await ref
          .read(activityRepositoryProvider)
          .logCompletion(_a.id, visitId: active?.visitId);
      ref.invalidate(dashboardProvider);
    } catch (e) {
      // Not critical: the user still completed the exercise.
      debugPrint('Could not save activity: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_a.title)),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_done) return _buildFinished();
    if (_index < 0) return _buildIntro();

    final step = _a.steps[_index];
    final isLast = _index == _a.steps.length - 1;

    return Column(
      children: [
        LinearProgressIndicator(value: (_index + 1) / _a.steps.length),
        Expanded(
          child: step.isBreathing
              ? BreathingStepView(
                  key: ValueKey('step-$_index'),
                  step: step,
                  onDone: _next,
                )
              : PromptStepView(
                  key: ValueKey('step-$_index'),
                  step: step,
                  isLast: isLast,
                  onNext: _next,
                ),
        ),
      ],
    );
  }

  Widget _buildIntro() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _a.type == 'breathing' ? Icons.air : Icons.spa,
                      size: 72,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(_a.title,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(_a.description,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    Chip(label: Text(_a.durationText)),
                    const SizedBox(height: 16),
                    Text(
                      'Find a comfortable spot. You can stop at any time.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          FilledButton(
            onPressed: _a.steps.isEmpty ? null : () => setState(() => _index = 0),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Widget _buildFinished() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.celebration, size: 72, color: scheme.primary),
                  const SizedBox(height: 24),
                  Text('Well done',
                      style: textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text(
                    'Take a moment to notice how you feel.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
