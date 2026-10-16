import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Simple bar chart of Stress Reduction Scores, oldest visit on the left.
/// Bars above the line = stress went down. Bars below = it went up.
class ReductionChart extends StatelessWidget {
  const ReductionChart({super.key, required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: CustomPaint(
        painter: _ReductionPainter(
          values: values,
          up: scheme.primary,
          down: scheme.error,
          axis: scheme.outlineVariant,
          text: scheme.onSurface,
        ),
      ),
    );
  }
}

class _ReductionPainter extends CustomPainter {
  _ReductionPainter({
    required this.values,
    required this.up,
    required this.down,
    required this.axis,
    required this.text,
  });

  final List<int> values;
  final Color up;
  final Color down;
  final Color axis;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxAbs = math.max(4, values.map((v) => v.abs()).reduce(math.max));
    final midY = size.height / 2;
    final usable = midY - 20; // room for the number labels

    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );

    final slot = size.width / values.length;
    final barW = math.min(slot * 0.55, 36.0);

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final h = (v.abs() / maxAbs) * usable;
      final x = i * slot + (slot - barW) / 2;
      final paint = Paint()..color = v >= 0 ? up : down;

      if (v != 0) {
        final rect = v > 0
            ? Rect.fromLTWH(x, midY - h, barW, h)
            : Rect.fromLTWH(x, midY, barW, h);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          paint,
        );
      }

      final label = TextPainter(
        text: TextSpan(
          text: v > 0 ? '+$v' : '$v',
          style: TextStyle(fontSize: 11, color: text),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelX = x + (barW - label.width) / 2;
      final labelY = v >= 0 ? midY - h - label.height - 2 : midY + h + 2;
      label.paint(canvas, Offset(labelX, labelY));
    }
  }

  @override
  bool shouldRepaint(covariant _ReductionPainter old) =>
      old.values != values ||
      old.up != up ||
      old.down != down ||
      old.axis != axis ||
      old.text != text;
}
