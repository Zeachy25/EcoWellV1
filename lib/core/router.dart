import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/activities/domain/activity_models.dart';
import '../features/activities/presentation/activity_list_screen.dart';
import '../features/activities/presentation/activity_runner_screen.dart';
import '../features/auth/presentation/complete_profile_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/legal_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/reset_code_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/verify_email_screen.dart';
import '../features/map/domain/green_space.dart';
import '../features/navigation/presentation/navigation_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/shell/presentation/main_shell.dart';
import '../features/visit/presentation/visit_flow_screen.dart';
import 'auth_flags.dart';
import 'config.dart';

/// Re-runs the router redirect whenever the login state changes.
/// Also notices the "password recovery" event (reset link opened).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    _sub = stream.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        passwordRecoveryActive = true;
      }
      notifyListeners();
    });
  }
  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Pages that only make sense when signed out.
const _signedOutOnlyPages = {
  '/onboarding',
  '/login',
  '/register',
  '/forgot-password',
  '/verify-email',
  '/reset-code',
};

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
  redirect: (context, state) {
    final loc = state.matchedLocation;

    // Reset-password flow takes priority over everything.
    if (passwordRecoveryActive) {
      return loc == '/reset-password' ? null : '/reset-password';
    }

    if (loc == '/splash' || loc == '/legal') return null;

    final loggedIn = supabase.auth.currentSession != null;
    final signedOutOnly = _signedOutOnlyPages.contains(loc);

    if (!loggedIn && !signedOutOnly) return '/login';
    if (loggedIn && signedOutOnly) return '/home';

    // The code screens need the email address passed in.
    if ((loc == '/verify-email' || loc == '/reset-code') &&
        state.extra is! String) {
      return '/login';
    }

    // The visit and directions screens need a place; without one, go home.
    if ((loc == '/visit' || loc == '/navigate') && state.extra is! GreenSpace) {
      return '/home';
    }
    if (loc == '/activity' && state.extra is! Activity) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(
      path: '/forgot-password',
      builder: (_, __) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/verify-email',
      builder: (_, state) => VerifyEmailScreen(email: state.extra! as String),
    ),
    GoRoute(
      path: '/reset-code',
      builder: (_, state) => ResetCodeScreen(email: state.extra! as String),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (_, __) => const ResetPasswordScreen(),
    ),
    GoRoute(path: '/legal', builder: (_, __) => const LegalScreen()),
    GoRoute(
      path: '/complete-profile',
      builder: (_, state) => CompleteProfileScreen(
        needsBirthdate: (state.extra as bool?) ?? true,
      ),
    ),
    // After login the user lands in the main app frame (Home tab first).
    GoRoute(path: '/home', builder: (_, __) => const MainShell()),
    // Guided activities: a list by type, and the step-by-step runner.
    GoRoute(
      path: '/activities/:type',
      builder: (_, state) =>
          ActivityListScreen(type: state.pathParameters['type'] ?? 'breathing'),
    ),
    GoRoute(
      path: '/activity',
      builder: (_, state) =>
          ActivityRunnerScreen(activity: state.extra! as Activity),
    ),
    // In-app walking directions to a green space.
    GoRoute(
      path: '/navigate',
      builder: (_, state) => NavigationScreen(space: state.extra! as GreenSpace),
    ),
    // A whole visit: before questions -> at the place -> after -> result.
    GoRoute(
      path: '/visit',
      builder: (_, state) => VisitFlowScreen(space: state.extra! as GreenSpace),
    ),
  ],
);
