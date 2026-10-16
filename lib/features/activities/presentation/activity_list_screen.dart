import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/activity_repository.dart';

/// Lists the activities of one type ("breathing" or "grounding").
class ActivityListScreen extends ConsumerWidget {
  const ActivityListScreen({super.key, required this.type});

  final String type;

  String get _title {
    switch (type) {
      case 'grounding':
        return 'Grounding exercises';
      case 'quick_run':
        return 'Quick Run';
      default:
        return 'Breathing exercises';
    }
  }

  IconData get _icon => type == 'grounding' ? Icons.spa : Icons.air;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activitiesByTypeProvider(type));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          debugPrint('Activities error: $e');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not load the exercises. '
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(activitiesByTypeProvider(type)),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No exercises yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final a = items[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/activity', extra: a),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Icon(_icon, color: scheme.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(a.description),
                              const SizedBox(height: 8),
                              Text(a.durationText,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
