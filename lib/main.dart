import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/deep_links.dart';
import 'core/router.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseKey, // sb_publishable_...
  );
  await _startLinkListener();
  runApp(const ProviderScope(child: EcoWellApp()));
}

Future<void> _startLinkListener() async {
  final links = AppLinks();
  final initial = await links.getInitialLink();
  if (initial != null) {
    pendingDeepLink = postRouteFromUri(initial);
  }
  links.uriLinkStream.listen((uri) {
    final route = postRouteFromUri(uri);
    if (route == null) return;
    if (supabase.auth.currentSession != null) {
      appRouter.go(route);
    } else {
      pendingDeepLink = route;
      appRouter.go('/login');
    }
  });
}

class EcoWellApp extends StatelessWidget {
  const EcoWellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EcoWell',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: appRouter,
    );
  }
}
