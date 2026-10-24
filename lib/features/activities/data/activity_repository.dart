import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/json_cache.dart';
import '../domain/activity_models.dart';

class ActivityRepository {
  ActivityRepository(this._client, this._cache);
  final SupabaseClient _client;
  final JsonCache _cache;

  /// type: "breathing" or "grounding". Shortest first.
  /// Cached per type so the guided activities (and the "+" menu) keep
  /// working inside a park with no signal.
  Future<List<Activity>> fetchByType(String type) async {
    try {
      final rows = await _client
          .from('activities')
          .select()
          .eq('type', type)
          .order('duration_sec')
          .timeout(const Duration(seconds: 8)) as List<dynamic>;
      await _cache.write(CacheKeys.activities(type), rows);
      return _parse(rows);
    } catch (e) {
      debugPrint('Activities ($type) fetch failed, trying cache: $e');
      final cached = await _cache.read(CacheKeys.activities(type));
      if (cached is List) return _parse(cached);
      rethrow;
    }
  }

  List<Activity> _parse(List<dynamic> rows) => [
        for (final r in rows)
          Activity.fromJson(Map<String, dynamic>.from(r as Map)),
      ];

  /// Saves that the user finished an activity (optionally during a visit).
  Future<void> logCompletion(String activityId, {String? visitId}) async {
    final uid = _client.auth.currentUser!.id;
    final row = {
      'user_id': uid,
      'activity_id': activityId,
    };
    if (visitId != null) row['visit_id'] = visitId;
    await _client.from('activity_logs').insert(row);
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(
    Supabase.instance.client,
    ref.watch(jsonCacheProvider),
  ),
);

final activitiesByTypeProvider =
    FutureProvider.autoDispose.family<List<Activity>, String>(
  (ref, type) => ref.watch(activityRepositoryProvider).fetchByType(type),
);
