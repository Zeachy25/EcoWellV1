import 'package:flutter/material.dart';

class QuietRatingStep extends StatefulWidget {
  const QuietRatingStep({
    super.key,
    required this.placeName,
    required this.onSubmit,
    this.busy = false,
  });

  final String placeName;
  final ValueChanged<int> onSubmit;
  final bool busy;

  @override
  State<QuietRatingStep> createState() => _QuietRatingStepState();
}

class _QuietRatingStepState extends State<QuietRatingStep> {
  static const _labels = [
    'Very noisy',
    'Somewhat noisy',
    'Okay',
    'Quiet',
    'Very quiet',
  ];
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.volume_down, size: 64, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'How quiet and calm did ${widget.placeName} feel?',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Your rating helps other people choose where to go.',
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  iconSize: 40,
                  onPressed: widget.busy ? null : () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating ? Icons.star : Icons.star_border,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 24,
            child: Text(_rating == 0 ? '' : _labels[_rating - 1]),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_rating == 0 || widget.busy)
                ? null
                : () => widget.onSubmit(_rating),
            child: widget.busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Finish visit'),
          ),
        ],
      ),
    );
  }
}
