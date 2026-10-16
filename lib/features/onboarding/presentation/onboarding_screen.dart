import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/data/onboarding_storage.dart';

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
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
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 180,
                          width: 180,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(p.icon, size: 88, color: scheme.primary),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p.description,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: active ? 24 : 8,
                  decoration: BoxDecoration(
                    color: active ? scheme.primary : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _isLast
                  ? Column(
                      children: [
                        FilledButton(
                          onPressed: () => _finish('/register'),
                          child: const Text('Get started'),
                        ),
                        TextButton(
                          onPressed: () => _finish('/login'),
                          child: const Text('I already have an account'),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'EcoWell is a wellness tool and not a substitute '
                          'for professional care.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        FilledButton(
                          onPressed: _next,
                          child: const Text('Next'),
                        ),
                        // Keeps the layout height the same as the last page
                        const SizedBox(height: 48),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
