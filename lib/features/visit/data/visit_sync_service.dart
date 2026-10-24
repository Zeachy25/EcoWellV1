import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/queued_visit.dart';
import '../domain/visit_models.dart';
import 'offline_visit_store.dart';

/// Sends visits that were recorded offline to Supabase.
///
/// It runs when the network comes back, when the app is opened again, and
/// right after a visit is finished while online. A local row is removed only
/// after the server has confirmed it, so a failed attempt is simply retried
/// later and nothing the user typed is lost.
///
/// Upload order for one visit: create the row (with the original entry
/// time) -> save the "before" answers -> close the visit through the
/// `finish_visit` RPC, which computes the scores and the streak.
class VisitSyncService {
  VisitSyncService({
    required SupabaseClient client,
    required OfflineVisitStore store,
  })  : _client = client,
        _store = store;

  final SupabaseClient _client;
  final OfflineVisitStore _store;

  /// Chained so two syncs never upload the same visit twice.
  Future<void> _last = Future<void>.value();

  /// Uploads every queued visit of the signed-in user.
  /// Returns true when at least one visit reached the server.
  Future<bool> syncAll() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final queued = await _store.pending(uid);
    if (queued.isEmpty) return false;

    var synced = false;
    for (final visit in queued) {
      try {
        await syncVisit(visit);
        synced = true;
      } catch (e) {
        debugPrint('Visit sync failed (${visit.id}): $e');
      }
    }
    if (synced) debugPrint('Visit sync: sent ${queued.length} queued visit(s)');
    return synced;
  }

  /// Uploads one visit. Returns the server's result when the visit was
  /// finished by this call, otherwise null. Throws when the upload fails
  /// (the row stays queued and is retried later).
  Future<VisitResult?> syncVisit(QueuedVisit visit) {
    final next = _last.then((_) => _sync(visit));
    _last = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<VisitResult?> _sync(QueuedVisit visit) async {
    var v = visit;

    if (v.serverVisitId == null) {
      final created = await _client.from('visits').insert({
        'user_id': v.userId,
        'place_id': v.placeId,
        'entry_time': v.entryTime.toUtc().toIso8601String(),
      }).select('id').single();
      v = v.copyWith(serverVisitId: created['id'] as String);
      await _store.attachServerId(visit.id, v.serverVisitId!);
    }

    // The assessment may already exist from an earlier attempt; a duplicate
    // key (23505) therefore just means "already uploaded".
    if (v.preAnswers != null) {
      final a = v.preAnswers!;
      try {
        await _client.from('assessments').insert({
          'visit_id': v.serverVisitId,
          'user_id': v.userId,
          'type': 'pre',
          'q1': a[0],
          'q2': a[1],
          'q3': a[2],
          'q4': a[3],
        });
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }
    }

    switch (v.status) {
      case QueuedVisitStatus.inProgress:
        return null; // still open on the phone, only mirrored on the server

      case QueuedVisitStatus.abandoned:
        await _client.from('visits').update({
          'status': 'abandoned',
          'exit_time': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', v.serverVisitId!);
        await _store.remove(visit.id);
        return null;

      case QueuedVisitStatus.pendingSync:
        final a = v.postAnswers!;
        final res = await _client.rpc('finish_visit', params: {
          'p_visit_id': v.serverVisitId,
          'p_q1': a[0],
          'p_q2': a[1],
          'p_q3': a[2],
          'p_q4': a[3],
          'p_quiet_rating': v.quietRating,
        });
        await _store.remove(visit.id);
        return VisitResult.fromJson(Map<String, dynamic>.from(res as Map));
    }
  }
}

final visitSyncServiceProvider = Provider<VisitSyncService>(
  (ref) => VisitSyncService(
    client: Supabase.instance.client,
    store: ref.watch(offlineVisitStoreProvider),
  ),
);
