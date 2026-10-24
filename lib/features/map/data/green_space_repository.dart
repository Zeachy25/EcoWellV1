import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/json_cache.dart';
import '../domain/green_space.dart';

class GreenSpaceRepository {
  GreenSpaceRepository(this._client, this._cache);
  final SupabaseClient _client;
  final JsonCache _cache;

  /// Loads every green space with its boundary and average Quiet Score.
  ///
  /// The list is also kept on the phone, so the map, the places section on
  /// Home and the geofence watcher keep working without a connection.
  Future<List<GreenSpace>> fetchAll() async {
    try {
      final rows = await _client
          .rpc('get_green_spaces')
          .timeout(const Duration(seconds: 8)) as List<dynamic>;
      await _cache.write(CacheKeys.greenSpaces, rows);
      return _parse(rows);
    } catch (e) {
      debugPrint('Green spaces fetch failed, trying cache: $e');
      final cached = await _cache.read(CacheKeys.greenSpaces);
      if (cached is List) return _parse(cached);
      rethrow;
    }
  }

  List<GreenSpace> _parse(List<dynamic> rows) => [
        for (final r in rows)
          GreenSpace.fromJson(Map<String, dynamic>.from(r as Map)),
      ];
}
