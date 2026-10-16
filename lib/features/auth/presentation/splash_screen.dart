import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../onboarding/data/onboarding_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  /// Logged in -> Home. New user -> Onboarding. Returning user -> Login.
  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final seenOnboarding = await OnboardingStorage.isSeen();
    if (!mounted) return;

    if (supabase.auth.currentSession != null) {
      context.go('/home');
    } else if (!seenOnboarding) {
      context.go('/onboarding');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primaryContainer,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa, size: 88, color: scheme.primary),
            const SizedBox(height: 16),
            Text('EcoWell',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Find calm in nature'),
          ],
        ),
      ),
    );
  }
}
