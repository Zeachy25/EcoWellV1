import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/domain/dashboard_models.dart';

/// Encouraging lines shown under the streak count. One is picked at random
/// each time the dialog opens if a generic message is needed.
const _messages = [
  'Nice work! Let\u2019s make it count tomorrow.',
  'You\u2019re building a great habit.',
  'One more day stronger.',
  'Nature is doing its thing.',
  'Consistency looks good on you.',
  'Keep the fire alive.',
  'Your streak is glowing.',
  'See you tomorrow?',
];

/// Shows the celebration dialog when the daily streak increased after a
/// finished visit. Call this after the result screen is already visible.
Future<void> showStreakPopup(BuildContext context, int streakCount) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Daily Streak',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) =>
        StreakPopup(streakCount: streakCount),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return ScaleTransition(
        scale: curved,
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

class StreakPopup extends ConsumerStatefulWidget {
  const StreakPopup({super.key, required this.streakCount});

  /// Total consecutive days, straight from the visit result.
  final int streakCount;

  @override
  ConsumerState<StreakPopup> createState() => _StreakPopupState();
}

class _StreakPopupState extends ConsumerState<StreakPopup> {
  late final String _message = _messages[Random().nextInt(_messages.length)];

  /// Days below a week stay in days; a full week or more is shown as weeks.
  bool get _inWeeks => widget.streakCount >= 7;

  String get _unitLabel {
    if (_inWeeks) {
      final w = widget.streakCount ~/ 7;
      return w == 1 ? 'week' : 'weeks';
    }
    return widget.streakCount == 1 ? 'day' : 'days';
  }

  String get _subtitleText {
    if (_inWeeks) {
      return _message;
    }
    return 'Let\u2019s make it Day ${widget.streakCount + 1} tomorrow';
  }

  /// Mon (1) through Sun (7) of the current calendar week that have a visit.
  /// Today always counts — the dialog only opens right after one.
  Set<int> _visitedWeekdays(DashboardData? dash) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    final visited = <int>{now.weekday};
    if (dash == null) return visited;
    for (final v in dash.recent) {
      final d = v.entryTime;
      final day = DateTime(d.year, d.month, d.day);
      final diff = day.difference(monday).inDays;
      if (diff >= 0 && diff < 7) visited.add(diff + 1);
    }
    return visited;
  }

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(dashboardProvider);
    final visited = _visitedWeekdays(
      dash.hasValue ? dash.value : dash.asData?.value,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Frosted background blur
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.white.withValues(alpha: 0.15)),
            ),

            // Confetti & streamers
            const CustomPaint(painter: _CelebrationConfettiPainter()),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.horizontalPadding(context),
                    vertical: Responsive.size(context, 12),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.forestDark,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: Responsive.size(context, 8)),

                        // Animated, realistic flame
                        _StreakFlameHero(
                          streakCount: widget.streakCount,
                          unitLabel: _unitLabel.toUpperCase(),
                        ),

                        SizedBox(height: Responsive.size(context, 20)),

                        // Taps inside the card shouldn't dismiss
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          child: _StreakBottomCard(
                            visited: visited,
                            subtitle: _subtitleText,
                          ),
                        ),

                        SizedBox(height: Responsive.size(context, 20)),

                        SizedBox(
                          width: double.infinity,
                          height:
                              Responsive.size(context, 50).clamp(44.0, 54.0),
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.streakOrange,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: AppColors.streakOrange
                                  .withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  Responsive.radius(context, 16),
                                ),
                              ),
                            ),
                            child: Text(
                              'Awesome, Keep Going!',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 15),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated flame hero
// ─────────────────────────────────────────────────────────────────────────────

/// Center hero: a living flame (swaying tongues, flicker, pulsing glow,
/// rising embers) with the streak number in its glowing core, plus the unit
/// label underneath.
class _StreakFlameHero extends StatefulWidget {
  const _StreakFlameHero({
    required this.streakCount,
    required this.unitLabel,
  });

  final int streakCount;
  final String unitLabel;

  @override
  State<_StreakFlameHero> createState() => _StreakFlameHeroState();
}

class _StreakFlameHeroState extends State<_StreakFlameHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Ember> _embers;

  @override
  void initState() {
    super.initState();
    // One seamless loop. All motion inside the painter uses whole-number
    // multiples of this cycle, so it never jumps when it restarts.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final rnd = Random(11);
    const count = 14;
    _embers = List.generate(count, (i) {
      return _Ember(
        offset: (i / count + rnd.nextDouble() * 0.05) % 1.0,
        cycles: rnd.nextBool() ? 1.0 : 2.0,
        xBias: rnd.nextDouble() * 2 - 1,
        size: 1.6 + rnd.nextDouble() * 1.8,
        drift: 0.5 + rnd.nextDouble(),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ignite: the flame grows up from its base when the popup opens.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: child,
            );
          },
          child: SizedBox(
            width: 200,
            height: 220,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _LiveFlamePainter(
                        animation: _controller,
                        embers: _embers,
                      ),
                    ),
                  ),
                ),
                // Streak number sitting in the glowing orb at the flame's
                // base, pulsing with it. Alignment y = 2 * orbY - 1, so it
                // matches the orb center at h * 0.72 in the painter.
                Positioned.fill(
                  child: Align(
                    alignment: const Alignment(0, 0.60),
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        final pulse =
                            1 + 0.035 * sin(_controller.value * 2 * pi * 2);
                        return Transform.scale(scale: pulse, child: child);
                      },
                      child: Text(
                        '${widget.streakCount}',
                        style: const TextStyle(
                          fontSize: 48,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD32F2F),
                          letterSpacing: -1,
                          shadows: [
                            Shadow(
                              color: Color(0x30D32F2F),
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 2),

        // Bold unit text with dripping paint accents
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Text(
              widget.unitLabel,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                color: Color(0xFFE5252A),
                shadows: [
                  Shadow(
                    color: Color(0x40E5252A),
                    offset: Offset(0, 3),
                    blurRadius: 6,
                  ),
                  Shadow(
                    color: Color(0x25000000),
                    offset: Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: -6,
              child: CustomPaint(
                size: const Size(96, 8),
                painter: _TextDripPainter(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Ember {
  const _Ember({
    required this.offset,
    required this.cycles,
    required this.xBias,
    required this.size,
    required this.drift,
  });

  final double offset; // start phase 0..1
  final double cycles; // whole number of rises per loop (seamless)
  final double xBias; // -1..1 horizontal spread
  final double size; // base radius
  final double drift; // sideways wobble amount
}

/// Draws a realistic flame every frame from layered, wobbling teardrop shapes:
/// glow -> side tongues -> outer flame -> mid flame -> white-hot core -> orb
/// -> rising embers.
class _LiveFlamePainter extends CustomPainter {
  _LiveFlamePainter({
    required this.animation,
    required this.embers,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<_Ember> embers;

  /// Builds one flame tongue. Base is fixed; the further up, the more it
  /// sways, wobbles at the edges, and flicks at the tip.
  Path _flame({
    required double cx,
    required double baseY,
    required double height,
    required double maxHalfW,
    required double phase,
    required double sway,
    double lean = 0,
  }) {
    final a = animation.value * 2 * pi;
    final h = height *
        (1 + 0.045 * sin(a * 2 + phase) + 0.025 * sin(a * 5 + phase * 2));

    const n = 36;
    final left = <Offset>[];
    final right = <Offset>[];

    for (var i = 0; i <= n; i++) {
      final t = i / n; // 0 = base, 1 = tip
      final y = baseY - h * t;

      // Teardrop profile: round belly low down, narrowing to a point.
      final profile = sin(pi * pow(t, 0.55));
      final wobble = 1 +
          0.07 * sin(a * 3 + t * 8 + phase) +
          0.04 * sin(a * 5 - t * 13 + phase * 2);
      final hw = maxHalfW * profile * wobble;

      final drift = sway *
              t *
              t *
              (0.7 * sin(a * 2 + phase) + 0.3 * sin(a * 3 + t * 3 + phase * 1.7)) +
          lean * t * t;
      final x = cx + drift;

      left.add(Offset(x - hw, y));
      right.add(Offset(x + hw, y));
    }

    final pts = [...left, ...right.reversed];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = Offset(
        (pts[i].dx + pts[i + 1].dx) / 2,
        (pts[i].dy + pts[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    path.close();
    return path;
  }

  void _fill(
    Canvas canvas,
    Path path,
    List<Color> colors, {
    double blur = 0,
  }) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(path.getBounds());
    if (blur > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final a = animation.value * 2 * pi;
    final cx = w / 2;
    final baseY = h * 0.97;

    // 1. Pulsing ambient glow
    final glowCenter = Offset(cx, h * 0.58);
    final glowR = w * 0.70 * (1 + 0.05 * sin(a * 2));
    canvas.drawCircle(
      glowCenter,
      glowR,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0x55FF7043),
            Color(0x22FF9100),
            Color(0x00FF9100),
          ],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: glowR)),
    );

    // 2. Side tongues (leaning out, moving out of sync with the main flame)
    _fill(
      canvas,
      _flame(
        cx: cx - w * 0.17,
        baseY: baseY - h * 0.03,
        height: h * 0.66,
        maxHalfW: w * 0.13,
        phase: 1.3,
        sway: w * 0.07,
        lean: -w * 0.09,
      ),
      const [Color(0xFFFF3D00), Color(0xFFFF6D00), Color(0xFFFF9100)],
      blur: 1.2,
    );
    _fill(
      canvas,
      _flame(
        cx: cx + w * 0.17,
        baseY: baseY - h * 0.03,
        height: h * 0.60,
        maxHalfW: w * 0.12,
        phase: 4.2,
        sway: w * 0.07,
        lean: w * 0.09,
      ),
      const [Color(0xFFFF3D00), Color(0xFFFF6D00), Color(0xFFFF9100)],
      blur: 1.2,
    );

    // 3. Outer flame (red-orange tip -> amber base)
    _fill(
      canvas,
      _flame(
        cx: cx,
        baseY: baseY,
        height: h * 0.93,
        maxHalfW: w * 0.37,
        phase: 0,
        sway: w * 0.08,
      ),
      const [
        Color(0xFFE53012),
        Color(0xFFFF3D00),
        Color(0xFFFF6D00),
        Color(0xFFFF9100),
        Color(0xFFFFB300),
      ],
      blur: 0.8,
    );

    // 4. Mid flame (orange -> yellow)
    _fill(
      canvas,
      _flame(
        cx: cx,
        baseY: baseY - h * 0.01,
        height: h * 0.74,
        maxHalfW: w * 0.27,
        phase: 2.1,
        sway: w * 0.06,
      ),
      const [
        Color(0xFFFF9100),
        Color(0xFFFFB300),
        Color(0xFFFFD54F),
        Color(0xFFFFEE58),
      ],
      blur: 1.5,
    );

    // 5. White-hot inner core
    _fill(
      canvas,
      _flame(
        cx: cx,
        baseY: baseY - h * 0.02,
        height: h * 0.52,
        maxHalfW: w * 0.17,
        phase: 3.7,
        sway: w * 0.04,
      ),
      const [Color(0xFFFFF176), Color(0xFFFFF9C4), Color(0xFFFFFFFF)],
      blur: 2.0,
    );

    // 6. Glowing orb that holds the streak number, sitting low in the flame's
    // belly (breathes with the flame)
    final orbCenter = Offset(cx, h * 0.75);
    final orbR = w * 0.20 * (1 + 0.035 * sin(a * 2));
    canvas.drawCircle(
      orbCenter,
      orbR,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFFDE7),
            Color(0xFFFFEE58),
            Color(0xFFFFD54F),
            Color(0x00FFB300),
          ],
          stops: [0.0, 0.35, 0.68, 0.88, 1.0],
        ).createShader(Rect.fromCircle(center: orbCenter, radius: orbR)),
    );

    // 7. Embers rising off the flame
    for (final e in embers) {
      final p = (animation.value * e.cycles + e.offset) % 1.0;
      final x = cx +
          e.xBias * w * 0.30 +
          sin(p * pi * 3 + e.offset * 2 * pi) * w * 0.05 * e.drift;
      final y = baseY - h * 0.25 - p * h * 0.85;
      final fadeIn = p < 0.1 ? p / 0.1 : 1.0;
      final alpha = ((1 - p) * fadeIn).clamp(0.0, 1.0);
      final radius = e.size * (1 - 0.65 * p);
      final color = Color.lerp(
        const Color(0xFFFFE082),
        const Color(0xFFFF6D00),
        p,
      )!;

      canvas.drawCircle(
        Offset(x, y),
        radius * 2.4,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: alpha * 0.95),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveFlamePainter oldDelegate) => false;
}

/// Drips hanging below the unit text.
class _TextDripPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5252A)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    final drips = [
      const Offset(10, 0),
      const Offset(10, 4),
      const Offset(22, 0),
      const Offset(22, 6),
      const Offset(36, 0),
      const Offset(36, 7),
      const Offset(48, 0),
      const Offset(48, 5),
      const Offset(62, 0),
      const Offset(62, 8),
      const Offset(74, 0),
      const Offset(74, 4),
      const Offset(86, 0),
      const Offset(86, 6),
    ];

    for (var i = 0; i < drips.length; i += 2) {
      canvas.drawLine(drips[i], drips[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly card
// ─────────────────────────────────────────────────────────────────────────────

/// Card with Mon-Sun tracker, divider, and encouraging text.
class _StreakBottomCard extends StatelessWidget {
  const _StreakBottomCard({
    required this.visited,
    required this.subtitle,
  });

  final Set<int> visited;
  final String subtitle;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final todayWeekday = DateTime.now().weekday;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.size(context, 12).clamp(10.0, 16.0),
        vertical: Responsive.size(context, 16).clamp(12.0, 18.0),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          Responsive.radius(context, 24).clamp(16.0, 24.0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F3223).withValues(alpha: 0.14),
            blurRadius: Responsive.size(context, 20).clamp(10.0, 20.0),
            offset: Offset(0, Responsive.size(context, 8).clamp(4.0, 8.0)),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 1; i <= 7; i++)
                Expanded(
                  child: _DayIndicator(
                    label: _days[i - 1],
                    isVisited: visited.contains(i),
                    isToday: i == todayWeekday,
                  ),
                ),
            ],
          ),

          SizedBox(height: Responsive.size(context, 16).clamp(10.0, 16.0)),

          Container(
            width: double.infinity,
            height: 1.0,
            color: const Color(0xFFE2EBE5),
          ),

          SizedBox(height: Responsive.size(context, 14).clamp(8.0, 14.0)),

          Text(
            'Nice work!',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.w800,
              color: AppColors.streakOrange,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: Responsive.size(context, 4)),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 13),
              fontWeight: FontWeight.w500,
              color: const Color(0xFF3B5045),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular day indicator for Monday through Sunday.
class _DayIndicator extends StatelessWidget {
  const _DayIndicator({
    required this.label,
    required this.isVisited,
    required this.isToday,
  });

  final String label;
  final bool isVisited;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final double circleSize = Responsive.size(context, 32).clamp(24.0, 36.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isVisited
                ? const Color(0xFF2E9E6B)
                : (isToday
                    ? const Color(0xFFE8F5EE)
                    : const Color(0xFFF5FAF7)),
            border: Border.all(
              color: isVisited
                  ? const Color(0xFF237E55)
                  : (isToday
                      ? const Color(0xFF38B289)
                      : const Color(0xFF90D5B7)),
              width: isToday ? 2.0 : 1.4,
            ),
            boxShadow: isVisited
                ? [
                    BoxShadow(
                      color: const Color(0xFF2E9E6B).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isVisited
                ? Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: Responsive.size(context, 18).clamp(14.0, 20.0),
                  )
                : (isToday
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF38B289),
                        ),
                      )
                    : null),
          ),
        ),
        SizedBox(height: Responsive.size(context, 6).clamp(3.0, 6.0)),
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 12),
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday ? AppColors.textPrimary : const Color(0xFF55695C),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confetti
// ─────────────────────────────────────────────────────────────────────────────

/// Festive celebration confetti with streamers and scattered flakes.
class _CelebrationConfettiPainter extends CustomPainter {
  const _CelebrationConfettiPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Winding party ribbons / streamers
    _drawStreamer(
      canvas,
      points: [
        Offset(w * 0.35, h * 0.12),
        Offset(w * 0.22, h * 0.20),
        Offset(w * 0.32, h * 0.29),
        Offset(w * 0.19, h * 0.38),
        Offset(w * 0.26, h * 0.46),
      ],
      color: const Color(0xFFBA68C8).withValues(alpha: 0.70), // Lavender
      width: 5.5,
    );

    _drawStreamer(
      canvas,
      points: [
        Offset(w * 0.78, h * 0.16),
        Offset(w * 0.88, h * 0.24),
        Offset(w * 0.80, h * 0.33),
        Offset(w * 0.90, h * 0.42),
      ],
      color: const Color(0xFFFFD54F).withValues(alpha: 0.75), // Golden
      width: 5.0,
    );

    _drawStreamer(
      canvas,
      points: [
        Offset(w * 0.16, h * 0.52),
        Offset(w * 0.26, h * 0.62),
        Offset(w * 0.12, h * 0.68),
      ],
      color: const Color(0xFFB0BEC5).withValues(alpha: 0.65), // Soft grey
      width: 4.5,
    );

    _drawStreamer(
      canvas,
      points: [
        Offset(w * 0.82, h * 0.46),
        Offset(w * 0.74, h * 0.54),
        Offset(w * 0.82, h * 0.62),
      ],
      color: const Color(0xFFFF8A80).withValues(alpha: 0.70), // Coral
      width: 4.5,
    );

    // 2. Scattered colorful confetti flakes
    final flakes = [
      _ConfettiPiece(Offset(w * 0.12, h * 0.08), 8, 16, -0.4, const Color(0xFF43A047)),
      _ConfettiPiece(Offset(w * 0.26, h * 0.05), 7, 14, 0.3, const Color(0xFFFFD54F)),
      _ConfettiPiece(Offset(w * 0.64, h * 0.06), 9, 22, -0.6, const Color(0xFFE91E63)),
      _ConfettiPiece(Offset(w * 0.82, h * 0.07), 10, 20, 0.5, const Color(0xFF00ACC1)),
      _ConfettiPiece(Offset(w * 0.68, h * 0.14), 8, 24, 0.2, const Color(0xFFE53935)),
      _ConfettiPiece(Offset(w * 0.86, h * 0.16), 11, 26, -0.3, const Color(0xFFFF7043)),
      _ConfettiPiece(Offset(w * 0.30, h * 0.20), 12, 16, 0.6, const Color(0xFFFFCA28)),
      _ConfettiPiece(Offset(w * 0.84, h * 0.25), 7, 13, -0.5, const Color(0xFF26C6DA)),
      _ConfettiPiece(Offset(w * 0.36, h * 0.27), 6, 12, 0.4, const Color(0xFFD81B60)),
      _ConfettiPiece(Offset(w * 0.10, h * 0.40), 9, 18, -0.7, const Color(0xFF78909C)),
      _ConfettiPiece(Offset(w * 0.92, h * 0.45), 7, 15, 0.3, const Color(0xFFFFB300)),
      _ConfettiPiece(Offset(w * 0.76, h * 0.56), 8, 16, -0.2, const Color(0xFFF06292)),
      _ConfettiPiece(Offset(w * 0.14, h * 0.55), 9, 17, 0.5, const Color(0xFFAB47BC)),
      _ConfettiPiece(Offset(w * 0.88, h * 0.64), 8, 15, -0.4, const Color(0xFF42A5F5)),
    ];

    for (final flake in flakes) {
      canvas.save();
      canvas.translate(flake.position.dx, flake.position.dy);
      canvas.rotate(flake.rotation);
      final paint = Paint()..color = flake.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: flake.width,
            height: flake.height,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  void _drawStreamer(
    Canvas canvas, {
    required List<Offset> points,
    required Color color,
    required double width,
  }) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConfettiPiece {
  const _ConfettiPiece(
    this.position,
    this.width,
    this.height,
    this.rotation,
    this.color,
  );

  final Offset position;
  final double width;
  final double height;
  final double rotation;
  final Color color;
}