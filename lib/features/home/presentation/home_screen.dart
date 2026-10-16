import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/auth_repository.dart';
import '../../map/data/map_providers.dart';
import '../../visit/data/visit_providers.dart';
import '../../visit/domain/visit_models.dart';
import '../data/profile_providers.dart';

/// Temporary Home tab: profile, streak, and a card for a visit in progress.
/// If the profile has no birthdate or no consent yet (Google sign-in, old
/// test accounts), it sends the user to the Complete Profile screen first.
/// Keep this check when the real Home content is built.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _resume(
    BuildContext context,
    WidgetRef ref,
    ActiveVisitInfo visit,
  ) async {
    final spaces = await ref.read(greenSpacesProvider.future);
    final match = spaces.where((s) => s.id == visit.placeId);
    if (match.isEmpty || !context.mounted) return;
    await context.push<void>('/visit', extra: match.first);
    ref.invalidate(activeVisitProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<Map<String, dynamic>>>(profileProvider, (_, next) {
      next.whenData((p) {
        if (p['birthdate'] == null || p['consented_at'] == null) {
          context.go('/complete-profile', extra: p['birthdate'] == null);
        }
      });
    });

    final profile = ref.watch(profileProvider);
    final activeAsync = ref.watch(activeVisitProvider);
    final active = activeAsync.hasValue ? activeAsync.value : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoWell'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: profile.when(
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load profile:\n$e', textAlign: TextAlign.center),
          ),
          data: (p) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Hello, ${p['full_name']}!',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Visit streak: ${p['streak_count']} days'),
                if (active != null) ...[
                  const SizedBox(height: 24),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.park),
                      title: Text('Visit in progress at ${active.placeName}'),
                      subtitle: const Text('Tap to continue your check-in'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _resume(context, ref, active),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
