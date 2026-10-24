import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../data/run_repository.dart';
import '../domain/run_models.dart';
import 'run_list_tile.dart';
import 'run_summary_view.dart';

/// Every Quick Run saved on this phone (including ones still waiting to
/// sync). Reads the local database, so it opens offline.
class RunHistoryScreen extends ConsumerWidget {
  const RunHistoryScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RunRecord record,
  ) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this run?'),
        content: Text(
          'The ${record.type.label.toLowerCase()} from '
          '${formatShortDate(record.startedAt)} will be removed '
          'from this phone and your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete != true) return;
    await ref.read(runRepositoryProvider).delete(record);
    ref.invalidate(runHistoryProvider);
  }

  void _showDetail(BuildContext context, WidgetRef ref, RunRecord record) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${record.type.label} \u00b7 ${formatShortDate(record.startedAt)} '
                '\u00b7 ${formatTime(record.startedAt)}',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              RunSummaryView(record: record, interactiveMap: true),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(context, ref, record);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete run'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(runHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quick Run history')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          debugPrint('Run history error: $e');
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Could not open your runs. Please try again.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        data: (runs) {
          if (runs.isEmpty) {
            return const Center(child: _NoRunsCard());
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: runs.length,
            itemBuilder: (context, i) {
              final run = runs[i];
              return RunListTile(
                record: run,
                onTap: () => _showDetail(context, ref, run),
              );
            },
          );
        },
      ),
    );
  }
}

class _NoRunsCard extends StatelessWidget {
  const _NoRunsCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.directions_run, color: scheme.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No runs yet. Record a walk or run with Quick Run and it '
                'will show up here - even without a connection.',
                style: textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
