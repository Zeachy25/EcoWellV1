import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/background_pattern.dart';
import '../data/onboarding_storage.dart';

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;
}

const _pages = [
  _OnboardingPage(
    icon: Icons.park,
    title: 'Find calm nearby',
    description:
        'Discover parks, mangroves and other green spaces around you, '
        'with Quiet Scores shared by other visitors.',
  ),
  _OnboardingPage(
    icon: Icons.psychology,
    title: 'See how you feel',
    description:
        'Answer a short 4-question check before and after each visit '
        'to see your Stress Reduction Score.',
  ),
  _OnboardingPage(
    icon: Icons.self_improvement,
    title: 'Relax with guidance',
    description:
        'Try breathing and grounding exercises, and chat with the '
        'AI coach when you need a little support.',
  ),
  _OnboardingPage(
    icon: Icons.trending_up,
    title: 'Build a healthy habit',
    description:
        'Keep your visit streak, track your progress, and share your '
        'moments with the EcoWell community.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Marks onboarding as seen, then goes to the given route.
  Future<void> _finish(String route) async {
    await OnboardingStorage.markSeen();
    if (!mounted) return;
    context.go(route);
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // --- design only: old look ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final badgeSize = size.width * 0.46;

    return Scaffold(
      backgroundColor: Colors.white,
      body: OrganicBackgroundCircles(
        child: SafeArea(
          child: Column(
            children: [
              // Skip button (hidden on the last page but keeps its space)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Visibility(
                    visible: !_isLast,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: TextButton(
                      onPressed: () => _finish('/login'),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 15),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2E8B57),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Brand title
              Text(
                'EcoWell',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 34),
                  fontWeight: FontWeight.w700,
                  fontFamily: 'serif',
                  color: const Color(0xFF132A1F),
                  letterSpacing: -0.5,
                ),
              ),

              const Spacer(),

              // Center circular hero badge (icon changes with the page)
              Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E6C54), Color(0xFF104434)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F3A2C).withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      _pages[_page].icon,
                      key: ValueKey(_page),
                      size: 76,
                      color: const Color(0xFF8DE2C8),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Bottom wave card
              ClipPath(
                clipper: _OnboardingWaveClipper(),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF65BA97), Color(0xFF1E503F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    Responsive.size(context, 28),
                    Responsive.size(context, 48),
                    Responsive.size(context, 28),
                    Responsive.size(context, 20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: Responsive.size(context, 140),
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: _pages.length,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (context, i) {
                            final p = _pages[i];
                            return SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.title,
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 23),
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.22,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    p.description,
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 13),
                                      fontWeight: FontWeight.w400,
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: Responsive.size(context, 12)),

                      // Pill indicator + Next arrow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: List.generate(_pages.length, (i) {
                              final active = i == _page;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.only(right: 6),
                                width: active
                                    ? Responsive.size(context, 40)
                                    : Responsive.size(context, 20),
                                height: Responsive.size(context, 6),
                                decoration: BoxDecoration(
                                  color: active
                                      ? Colors.black
                                      : Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),

                          // Next arrow (hidden on the last page, keeps space)
                          Visibility(
                            visible: !_isLast,
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            child: GestureDetector(
                              onTap: _next,
                              child: Container(
                                width: Responsive.size(context, 48),
                                height: Responsive.size(context, 48),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.16),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: const Color(0xFF164837),
                                  size: Responsive.size(context, 24),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Last page: Get started / I already have an account
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: _isLast
                            ? Column(
                                children: [
                                  SizedBox(
                                      height: Responsive.size(context, 16)),
                                  Container(
                                    width: double.infinity,
                                    height: Responsive.size(context, 54),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                          Responsive.radius(context, 14)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.16),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _finish('/register'),
                                        borderRadius: BorderRadius.circular(
                                            Responsive.radius(context, 14)),
                                        child: Center(
                                          child: Text(
                                            'Get started',
                                            style: TextStyle(
                                              fontSize: Responsive.fontSize(
                                                  context, 18),
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF164837),
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                      height: Responsive.size(context, 4)),
                                  Center(
                                    child: TextButton(
                                      onPressed: () => _finish('/login'),
                                      child: Text(
                                        'I already have an account',
                                        style: TextStyle(
                                          fontSize:
                                              Responsive.fontSize(context, 14),
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'EcoWell is a wellness tool and not a substitute '
                                    'for professional care.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize:
                                          Responsive.fontSize(context, 11),
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asymmetric curved wave clipper for the bottom card (from the old design)
class _OnboardingWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.moveTo(0, 36);
    path.cubicTo(
      size.width * 0.25, 0,
      size.width * 0.65, 44,
      size.width, 24,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}