import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/green_space.dart';

class GreenSpaceRepository {
  GreenSpaceRepository(this._client);
  final SupabaseClient _client;

  /// Loads every green space with its boundary and average Quiet Score.
  Future<List<GreenSpace>> fetchAll() async {
    final rows = await _client.rpc('get_green_spaces') as List<dynamic>;
    return rows
        .map((r) => GreenSpace.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
