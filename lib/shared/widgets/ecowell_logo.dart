import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class EcoWellLeafIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const EcoWellLeafIcon({
    super.key,
    this.size = 28,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LeafPainter(color: color ?? AppColors.mintGreen),
    );
  }
}

class _LeafPainter extends CustomPainter {
  final Color color;

  _LeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Organic slanted leaf shape matching EcoWell branding
    path.moveTo(w * 0.15, h * 0.85);
    path.cubicTo(w * 0.1, h * 0.4, w * 0.4, h * 0.1, w * 0.85, h * 0.15);
    path.cubicTo(w * 0.9, h * 0.6, w * 0.6, h * 0.9, w * 0.15, h * 0.85);
    path.close();

    canvas.drawPath(path, paint);

    // Subtle leaf vein
    final veinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;

    final veinPath = Path();
    veinPath.moveTo(w * 0.25, h * 0.75);
    veinPath.quadraticBezierTo(w * 0.45, h * 0.55, w * 0.72, h * 0.28);

    canvas.drawPath(veinPath, veinPaint);
  }

  @override
  bool shouldRepaint(covariant _LeafPainter oldDelegate) =>
      oldDelegate.color != color;
}

class EcoWellLogo extends StatelessWidget {
  final double size;
  final Color textColor;
  final Color leafColor;
  final bool isVertical;

  const EcoWellLogo({
    super.key,
    this.size = 24,
    this.textColor = AppColors.forestDark,
    this.leafColor = AppColors.mintGreen,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final leafWidget = EcoWellLeafIcon(size: size * 1.1, color: leafColor);
    final textWidget = Text(
      'EcoWell',
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        fontFamily: 'serif',
        color: textColor,
        letterSpacing: 0.2,
      ),
    );

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          leafWidget,
          const SizedBox(height: 8),
          textWidget,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leafWidget,
        const SizedBox(width: 8),
        textWidget,
      ],
    );
  }
}
