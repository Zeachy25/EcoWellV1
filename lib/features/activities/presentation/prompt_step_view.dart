import 'package:flutter/material.dart';

import '../domain/activity_models.dart';

/// A text step: a title, a short instruction, and a Next button.
class PromptStepView extends StatelessWidget {
  const PromptStepView({
    super.key,
    required this.step,
    required this.isLast,
    required this.onNext,
  });

  final ActivityStep step;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
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
                    Icon(Icons.spa, size: 56, color: scheme.primary),
                    const SizedBox(height: 24),
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      step.text,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
          FilledButton(
            onPressed: onNext,
            child: Text(isLast ? 'Finish' : 'Next'),
          ),
        ],
      ),
    );
  }
}
