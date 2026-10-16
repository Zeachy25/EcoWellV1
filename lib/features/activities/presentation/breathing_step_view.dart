import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/activity_models.dart';

/// An animated breathing guide: a circle that grows while you breathe in and
/// shrinks while you breathe out, with the phase name and a countdown.
class BreathingStepView extends StatefulWidget {
  const BreathingStepView({
    super.key,
    required this.step,
    required this.onDone,
  });

  final ActivityStep step;
  final VoidCallback onDone;

  @override
  State<BreathingStepView> createState() => _BreathingStepViewState();
}

class _BreathingStepViewState extends State<BreathingStepView> {
  Timer? _timer;
  int _round = 1;
  int _phaseIndex = 0;
  late int _secondsLeft;
  double _scale = 0.5;
  bool _paused = false;

  List<BreathPhase> get _phases => widget.step.phases;
  BreathPhase get _phase => _phases[_phaseIndex];

  @override
  void initState() {
    super.initState();
    if (_phases.isEmpty) {
      // Nothing to show: skip this step.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
      _secondsLeft = 0;
      return;
    }
    _secondsLeft = _phase.seconds;
    // Start small, then grow during the first "breathe in".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _scale = _phase.to ?? _scale);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (_paused || !mounted) return;
    if (_secondsLeft > 1) {
      setState(() => _secondsLeft--);
    } else {
      _nextPhase();
    }
  }

  void _nextPhase() {
    var next = _phaseIndex + 1;
    var round = _round;
    if (next >= _phases.length) {
      next = 0;
      round++;
    }
    if (round > widget.step.rounds) {
      _timer?.cancel();
      HapticFeedback.mediumImpact();
      widget.onDone();
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _phaseIndex = next;
      _round = round;
      _secondsLeft = _phases[next].seconds;
      final to = _phases[next].to;
      if (to != null) _scale = to;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_phases.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(widget.step.title, style: textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Round $_round of ${widget.step.rounds}',
              style: textTheme.bodyMedium),
          Expanded(
            child: Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedScale(
                      scale: _scale,
                      duration: Duration(seconds: _phase.seconds),
                      curve: Curves.easeInOut,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primaryContainer,
                          border: Border.all(color: scheme.primary, width: 3),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _phase.label,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          '$_secondsLeft',
                          style: textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _paused = !_paused),
                icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                label: Text(_paused ? 'Resume' : 'Pause'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  _timer?.cancel();
                  widget.onDone();
                },
                child: const Text('Skip'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
