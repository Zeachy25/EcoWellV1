import 'package:flutter/material.dart';

/// Renders the soft organic circular background line patterns from the mockups
class OrganicBackgroundCircles extends StatelessWidget {
  final Widget child;

  const OrganicBackgroundCircles({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _OrganicCirclePainter(),
          ),
        ),
        child,
      ],
    );
  }
}

class _OrganicCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF86D5B4).withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = const Color(0xFFDCF4EA).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final subtleLinePaint = Paint()
      ..color = const Color(0xFF72C8A5).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    // Top-left large outline ring
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.12), size.width * 0.42, linePaint);

    // Top-right soft filled circle
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.16), size.width * 0.24, fillPaint);

    // Center-top large enclosing ring
    canvas.drawCircle(Offset(size.width * 0.46, size.height * 0.24), size.width * 0.52, subtleLinePaint);

    // Mid-left soft pastel bubble
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.46), size.width * 0.20, fillPaint);

    // Mid-right outline ring
    canvas.drawCircle(Offset(size.width * 0.95, size.height * 0.45), size.width * 0.36, linePaint);

    // Lower-left large ring
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.70), size.width * 0.46, linePaint);

    // Bottom-right decorative ring
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.92), size.width * 0.44, subtleLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
