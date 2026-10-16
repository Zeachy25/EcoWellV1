import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_models.dart';

class ActivityRepository {
  ActivityRepository(this._client);
  final SupabaseClient _client;

  /// type: "breathing", "grounding" or "quick_run". Shortest first.
  Future<List<Activity>> fetchByType(String type) async {
    final rows = await _client
        .from('activities')
        .select()
        .eq('type', type)
        .order('duration_sec') as List<dynamic>;
    return rows
        .map((r) => Activity.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Saves that the user finished an activity (optionally during a visit).
  Future<void> logCompletion(String activityId, {String? visitId}) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('activity_logs').insert({
      'user_id': uid,
      'activity_id': activityId,
      if (visitId != null) 'visit_id': visitId,
    });
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(Supabase.instance.client),
);

final activitiesByTypeProvider =
    FutureProvider.autoDispose.family<List<Activity>, String>(
  (ref, type) => ref.watch(activityRepositoryProvider).fetchByType(type),
);
