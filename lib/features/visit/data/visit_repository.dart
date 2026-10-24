import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/pss4.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/json_cache.dart';
import '../../map/domain/green_space.dart';
import '../domain/queued_visit.dart';
import '../domain/visit_models.dart';
import 'offline_visit_store.dart';
import 'visit_sync_service.dart';

/// Visits. Online it talks to Supabase exactly as it always did; without a
/// connection every step is written to the phone's `offline_visits` table
/// and [VisitSyncService] uploads it when the network comes back.
class VisitRepository {
  VisitRepository(
    this._client, {
    required OfflineVisitStore store,
    required VisitSyncService sync,
    required ConnectivityService connectivity,
    required JsonCache cache,
  })  : _store = store,
        _sync = sync,
        _connectivity = connectivity,
        _cache = cache;

  final SupabaseClient _client;
  final OfflineVisitStore _store;
  final VisitSyncService _sync;
  final ConnectivityService _connectivity;
  final JsonCache _cache;

  String? get _uid => _client.auth.currentUser?.id;

  /// Resumes the user's open visit at this place, or starts a new one.
  /// An open visit at a DIFFERENT place is marked abandoned first.
  Future<ActiveVisit> startOrResume(GreenSpace space) async {
    final uid = _uid;

    // A visit opened offline stays open on the phone until it is synced.
    if (uid != null) {
      final queued = await _store.active(uid);
      if (queued != null) {
        if (queued.placeId == space.id) {
          return ActiveVisit(
            id: queued.id,
            entryTime: queued.entryTime,
            hasPre: queued.preAnswers != null,
          );
        }
        await _store.abandon(queued.id);
        await _syncQuietly(queued.copyWith(status: QueuedVisitStatus.abandoned));
      }
    }

    if (_connectivity.isOnline) {
      try {
        return await _startOnline(space);
      } catch (e) {
        debugPrint('Start visit online failed, recording offline: $e');
      }
    }
    return _startOffline(space);
  }

  Future<ActiveVisit> _startOnline(GreenSpace space) async {
    final placeId = space.id;
    final existing = await _client
        .from('visits')
        .select('id, place_id, entry_time')
        .eq('status', 'in_progress')
        .maybeSingle();

    final String visitId;
    final DateTime entryTime;

    if (existing != null && existing['place_id'] == placeId) {
      visitId = existing['id'] as String;
      entryTime = DateTime.parse(existing['entry_time'] as String);
    } else {
      if (existing != null) {
        await abandonVisit(existing['id'] as String);
      }
      final created = await _client
          .from('visits')
          .insert({'user_id': _uid, 'place_id': placeId})
          .select('id, entry_time')
          .single();
      visitId = created['id'] as String;
      entryTime = DateTime.parse(created['entry_time'] as String);
    }

    final pre = await _client
        .from('assessments')
        .select('id')
        .eq('visit_id', visitId)
        .eq('type', 'pre')
        .maybeSingle();

    return ActiveVisit(
      id: visitId,
      entryTime: entryTime.toLocal(),
      hasPre: pre != null,
    );
  }

  Future<ActiveVisit> _startOffline(GreenSpace space) async {
    final uid = _uid;
    if (uid == null) {
      throw StateError('Sign in to start a visit.');
    }
    final queued = await _store.start(
      userId: uid,
      placeId: space.id,
      placeName: space.name,
    );
    return ActiveVisit(
      id: queued.id,
      entryTime: queued.entryTime,
      hasPre: queued.preAnswers != null,
    );
  }

  /// Saves the "before" PSS-4 answers (4 numbers, 0-4 each).
  Future<void> savePreAssessment(String visitId, List<int> answers) async {
    final queued = await _store.find(visitId);
    if (queued != null) {
      await _store.savePre(visitId, answers);
      return;
    }
    await _client.from('assessments').insert({
      'visit_id': visitId,
      'user_id': _uid,
      'type': 'pre',
      'q1': answers[0],
      'q2': answers[1],
      'q3': answers[2],
      'q4': answers[3],
    });
  }

  /// Saves the "after" answers + Quiet Score and closes the visit.
  ///
  /// Online this is one atomic database call (`finish_visit`). Offline the
  /// answers are queued, a locally calculated result is returned at once and
  /// the real one replaces it as soon as the queue is synced.
  Future<VisitResult> finishVisit(
    String visitId,
    List<int> answers,
    int quietRating,
  ) async {
    final queued = await _store.find(visitId);
    if (queued == null) {
      final res = await _client.rpc('finish_visit', params: {
        'p_visit_id': visitId,
        'p_q1': answers[0],
        'p_q2': answers[1],
        'p_q3': answers[2],
        'p_q4': answers[3],
        'p_quiet_rating': quietRating,
      });
      return VisitResult.fromJson(Map<String, dynamic>.from(res as Map));
    }

    await _store.finish(visitId, answers, quietRating);
    final finished = await _store.find(visitId) ?? queued;

    if (_connectivity.isOnline) {
      try {
        final serverResult = await _sync.syncVisit(finished);
        if (serverResult != null) return serverResult;
      } catch (e) {
        debugPrint('Finish visit sync failed, will retry later: $e');
      }
    }
    return _localResult(finished, answers);
  }

  /// The user's open visit (if any), with the place name. A visit recorded
  /// offline is shown first, so Home can resume it without a connection.
  Future<ActiveVisitInfo?> fetchActiveVisit() async {
    final uid = _uid;
    if (uid != null) {
      final queued = await _store.active(uid);
      if (queued != null) {
        return ActiveVisitInfo(
          // The server id once it exists, so logs of linked activities
          // (and other writes) can go straight to Supabase.
          visitId: queued.serverVisitId ?? queued.id,
          placeId: queued.placeId,
          placeName: queued.placeName,
          entryTime: queued.entryTime,
        );
      }
    }

    final row = await _client
        .from('visits')
        .select('id, place_id, entry_time, green_spaces(name)')
        .eq('status', 'in_progress')
        .maybeSingle();
    if (row == null) return null;
    final place = row['green_spaces'];
    return ActiveVisitInfo(
      visitId: row['id'] as String,
      placeId: row['place_id'] as String,
      placeName: place is Map
          ? ((place['name'] as String?) ?? 'a green space')
          : 'a green space',
      entryTime: DateTime.parse(row['entry_time'] as String).toLocal(),
    );
  }

  Future<void> abandonVisit(String visitId) async {
    final queued = await _store.find(visitId);
    if (queued != null) {
      await _store.abandon(visitId);
      final updated = await _store.find(visitId);
      await _syncQuietly(updated ?? queued.copyWith(
        status: QueuedVisitStatus.abandoned,
      ));
      return;
    }
    await _client.from('visits').update({
      'status': 'abandoned',
      'exit_time': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', visitId);
  }

  /// Uploads a queued visit when the network is up, but never fails the UI:
  /// the row stays queued and the next sync picks it up.
  Future<void> _syncQuietly(QueuedVisit visit) async {
    if (!_connectivity.isOnline) return;
    try {
      await _sync.syncVisit(visit);
    } catch (e) {
      debugPrint('Queued visit sync failed, will retry later: $e');
    }
  }

  /// Result shown right away when the visit was saved on the phone.
  /// Scores use the same rule as the database (items 2 and 3 reversed);
  /// the streak is whatever the last synced profile had, because the server
  /// decides the final streak when the queue is uploaded.
  Future<VisitResult> _localResult(QueuedVisit visit, List<int> answers) async {
    final pre = pss4Total(visit.preAnswers ?? const [0, 0, 0, 0]);
    final post = pss4Total(answers);
    final streak = await _cachedStreak();
    return VisitResult(
      preScore: pre,
      postScore: post,
      stressReductionScore: pre - post,
      streakCount: streak,
      longestStreak: streak,
    );
  }

  /// The last synced profile's streak, or 0 when it was never cached.
  Future<int> _cachedStreak() async {
    final raw = await _cache.read(CacheKeys.profile);
    final streak = raw is Map ? raw['streak_count'] : null;
    return streak is num ? streak.toInt() : 0;
  }
}

final visitRepositoryProvider = Provider<VisitRepository>(
  (ref) => VisitRepository(
    Supabase.instance.client,
    store: ref.watch(offlineVisitStoreProvider),
    sync: ref.watch(visitSyncServiceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
    cache: ref.watch(jsonCacheProvider),
  ),
);
