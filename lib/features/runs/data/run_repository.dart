import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/run_models.dart';
import 'run_store.dart';

/// Saves Quick Runs on the phone and reads the local history. Every write
/// goes to SQLite first, so recording, finishing and browsing runs all work
/// without a connection; `RunSyncService` uploads the finished ones later.
class RunRepository {
  RunRepository({required this.store, required this.client});

  final RunStore store;
  final SupabaseClient client;

  String? get currentUserId => client.auth.currentUser?.id;

  /// Persists a finished run as `pendingSync`. The local id is kept as the
  /// server id, so a retried upload cannot duplicate the row.
  Future<void> save(RunRecord record) {
    return store.save(record.copyWith(status: RunStatus.pendingSync));
  }

  /// Saves / refreshes the in-progress checkpoint of the active run.
  Future<void> saveCheckpoint(RunRecord record) {
    return store.save(record.copyWith(status: RunStatus.active));
  }

  Future<void> discardCheckpoint(String id) => store.remove(id);

  /// The unfinished run left behind if the app was killed mid-run.
  Future<RunRecord?> activeRun() async {
    final uid = currentUserId;
    if (uid == null) return null;
    return store.active(uid);
  }

  Future<List<RunRecord>> history() async {
    final uid = currentUserId;
    if (uid == null) return const [];
    return store.history(uid);
  }

  /// Deletes a run from the phone and, best effort, from the server.
  Future<void> delete(RunRecord record) async {
    await store.remove(record.id);
    if (record.status != RunStatus.synced) return;
    try {
      await client.from('runs').delete().eq('id', record.id);
    } catch (e) {
      // Offline or already gone: the local copy is removed either way.
    }
  }
}

final runRepositoryProvider = Provider<RunRepository>((ref) {
  return RunRepository(
    store: ref.watch(runStoreProvider),
    client: Supabase.instance.client,
  );
});

/// The saved runs of the signed-in user, newest first, straight from the
/// local database so the list opens offline. Refresh after every save.
final runHistoryProvider = FutureProvider<List<RunRecord>>((ref) {
  return ref.watch(runRepositoryProvider).history();
});
