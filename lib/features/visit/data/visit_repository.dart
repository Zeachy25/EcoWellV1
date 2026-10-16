import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/visit_models.dart';

class VisitRepository {
  VisitRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  /// Resumes the user's open visit at this place, or starts a new one.
  /// An open visit at a DIFFERENT place is marked abandoned first.
  Future<ActiveVisit> startOrResume(String placeId) async {
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

  /// Saves the "before" PSS-4 answers (4 numbers, 0-4 each).
  Future<void> savePreAssessment(String visitId, List<int> answers) {
    return _client.from('assessments').insert({
      'visit_id': visitId,
      'user_id': _uid,
      'type': 'pre',
      'q1': answers[0],
      'q2': answers[1],
      'q3': answers[2],
      'q4': answers[3],
    });
  }

  /// Saves the "after" answers + Quiet Score and closes the visit
  /// (one atomic database call). Returns the scores and streak.
  Future<VisitResult> finishVisit(
    String visitId,
    List<int> answers,
    int quietRating,
  ) async {
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

  /// The user's open visit (if any), with the place name.
  Future<ActiveVisitInfo?> fetchActiveVisit() async {
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

  Future<void> abandonVisit(String visitId) {
    return _client.from('visits').update({
      'status': 'abandoned',
      'exit_time': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', visitId);
  }
}

final visitRepositoryProvider = Provider<VisitRepository>(
  (ref) => VisitRepository(Supabase.instance.client),
);
