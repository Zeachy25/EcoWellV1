import 'package:flutter/material.dart';

/// Design only: photo card, floating photos and dotted accents.
/// All sizes come from the reference design (578 x 372 units) and scale
/// with the available width.
class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key});

  /// Height divided by width of the whole banner.
  /// home_screen.dart uses this as HeroBanner.aspect.
  static const double aspect = 372 / 578;

  // Your file names in assets/images/
  static const _bg = 'assets/images/bg.jpg'; // tree on the hill
  static const _float1 = 'assets/images/float1.jpg'; // middle (blue sky)
  static const _float2 = 'assets/images/f2.jpg'; // top right (sunset kids)
  static const _float3 = 'assets/images/f3.jpg'; // bottom right (lake)
  static const _float4 = 'assets/images/f4.jpg';

  static const _skyBlue = Color(0xFFC8FBF6);

  Widget _img(String path) => Image.asset(
        path,
        fit: BoxFit.cover,
        // Placeholder instead of a crash if a file is missing.
        errorBuilder: (_, _, _) => Container(color: _skyBlue),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = w * aspect;
        // One unit of the reference design in real pixels.
        double u(double v) => v * w / 578;

        Widget photo(
          String path, {
          required double l,
          required double t,
          required double width,
          required double height,
          required double radius,
        }) {
          return Positioned(
            left: u(l),
            top: u(t),
            width: u(width),
            height: u(height),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(u(radius)),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: u(12),
                    offset: Offset(u(3), u(6)),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(u(radius) - 2),
                child: _img(path),
              ),
            ),
          );
        }

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Photo card
              Positioned(
                left: u(24),
                top: u(60),
                width: u(530),
                height: u(279),
                child: Container(
                  decoration: BoxDecoration(
                    color: _skyBlue,
                    borderRadius: BorderRadius.circular(u(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: u(16),
                        offset: Offset(u(5), u(8)),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(u(32)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _img(_bg),
                        // Light fade so the text stays readable
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.25),
                              ],
                              begin: Alignment.center,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        Positioned(
                          left: u(40),
                          bottom: u(18),
                          child: Text(
                            'FIND YOUR\nNEXT GREEN ESCAPE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: u(24),
                              letterSpacing: 1,
                              height: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Dotted accents
              Positioned(
                left: u(367),
                top: u(112),
                child: _DotGrid(
                  cols: 15,
                  rows: 6,
                  gap: u(9),
                  radius: u(1.5),
                  color: const Color(0xFF1B2A41).withValues(alpha: 0.85),
                ),
              ),
              Positioned(
                left: u(282),
                top: u(269),
                child: _DotGrid(
                  cols: 11,
                  rows: 3,
                  gap: u(8),
                  radius: u(1.5),
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),

              // Floating photos
              photo(_float1, l: 265, t: 129, width: 123, height: 123, radius: 18),
              photo(_float2, l: 421, t: 0, width: 157, height: 150, radius: 16),
              photo(_float4, l: 493, t: 185, width: 85, height: 85, radius: 8),
              photo(_float3, l: 400, t: 292, width: 95, height: 95, radius: 9),
            ],
          ),
        );
      },
    );
  }
}

class _DotGrid extends StatelessWidget {
  final int cols;
  final int rows;
  final double gap;
  final double radius;
  final Color color;
  const _DotGrid({
    required this.cols,
    required this.rows,
    required this.gap,
    required this.radius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(cols * gap, rows * gap),
      painter: _DotPainter(cols, rows, gap, radius, color),
    );
  }
}

class _DotPainter extends CustomPainter {
  final int cols;
  final int rows;
  final double gap;
  final double radius;
  final Color color;
  _DotPainter(this.cols, this.rows, this.gap, this.radius, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(c * gap + gap / 2, r * gap + gap / 2),
          radius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) =>
      old.cols != cols ||
      old.rows != rows ||
      old.gap != gap ||
      old.radius != radius ||
      old.color != color;
}