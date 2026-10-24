import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/run_models.dart';
import 'run_store.dart';

/// Uploads finished Quick Runs to Supabase. Mirrors `VisitSyncService`:
/// runs when the network comes back, when the app is opened again, and
/// right after a run is saved while online. A local row only changes after
/// the server has confirmed it, so a failed attempt is simply retried.
///
/// The insert sends the phone's own id as the primary key; if the upload
/// actually succeeded but the response was lost, the retry hits the
/// duplicate-key path (23505) and is treated as done instead of inserting
/// a second copy.
class RunSyncService {
  RunSyncService({required SupabaseClient client, required RunStore store})
      : _client = client,
        _store = store;

  final SupabaseClient _client;
  final RunStore _store;

  /// Chained so two syncs never upload the same run twice.
  Future<void> _last = Future<void>.value();

  /// Uploads every queued run of the signed-in user.
  /// Returns true when at least one run reached the server.
  Future<bool> syncAll() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final queued = await _store.pendingSync(uid);
    if (queued.isEmpty) return false;

    var synced = false;
    for (final run in queued) {
      try {
        await syncRun(run);
        synced = true;
      } catch (e) {
        debugPrint('Run sync failed (${run.id}): $e');
      }
    }
    if (synced) debugPrint('Run sync: sent ${queued.length} queued run(s)');
    return synced;
  }

  /// Uploads one run. Throws when the upload fails (the row stays queued).
  Future<void> syncRun(RunRecord run) {
    final next = _last.then((_) => _sync(run));
    _last = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _sync(RunRecord run) async {
    try {
      await _client.from('runs').insert(run.toInsertJson());
    } on PostgrestException catch (e) {
      // 23505 = the row already exists: an earlier attempt reached the
      // server but its response was lost. Treat it as synced.
      if (e.code != '23505') rethrow;
    }
    await _store.markSynced(run.id);
  }
}

final runSyncServiceProvider = Provider<RunSyncService>(
  (ref) => RunSyncService(
    client: Supabase.instance.client,
    store: ref.watch(runStoreProvider),
  ),
);
