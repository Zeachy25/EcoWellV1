import 'package:flutter/material.dart';

import '../../../core/constants/pss4.dart';

/// Shows the 4 PSS-4 questions one at a time, then calls onSubmit with the
/// four answers (0-4 each).
class PssQuestionnaire extends StatefulWidget {
  const PssQuestionnaire({
    super.key,
    required this.title,
    required this.intro,
    required this.submitLabel,
    required this.onSubmit,
    this.busy = false,
  });

  final String title;
  final String intro;
  final String submitLabel;
  final ValueChanged<List<int>> onSubmit;
  final bool busy;

  @override
  State<PssQuestionnaire> createState() => _PssQuestionnaireState();
}

class _PssQuestionnaireState extends State<PssQuestionnaire> {
  final List<int?> _answers = List<int?>.filled(pss4Questions.length, null);
  int _i = 0;

  bool get _isLast => _i == pss4Questions.length - 1;

  void _next() {
    if (_isLast) {
      widget.onSubmit(_answers.map((a) => a!).toList());
    } else {
      setState(() => _i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selected = _answers[_i];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(widget.intro),
          const SizedBox(height: 20),
          LinearProgressIndicator(value: (_i + 1) / pss4Questions.length),
          const SizedBox(height: 8),
          Text('Question ${_i + 1} of ${pss4Questions.length}',
              style: textTheme.bodySmall),
          const SizedBox(height: 16),
          Text(pss4Questions[_i], style: textTheme.titleMedium),
          const SizedBox(height: 16),
          for (var v = 0; v < pssOptions.length; v++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: selected == v
                  ? FilledButton(
                      onPressed: () => setState(() => _answers[_i] = v),
                      child: Text(pssOptions[v]),
                    )
                  : OutlinedButton(
                      onPressed: () => setState(() => _answers[_i] = v),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(pssOptions[v]),
                    ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_i > 0)
                TextButton(
                  onPressed: widget.busy ? null : () => setState(() => _i--),
                  child: const Text('Back'),
                ),
              const Spacer(),
              SizedBox(
                width: 180,
                child: FilledButton(
                  onPressed:
                      (selected == null || widget.busy) ? null : _next,
                  child: widget.busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isLast ? widget.submitLabel : 'Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
