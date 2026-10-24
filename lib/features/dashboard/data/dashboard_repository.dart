import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/json_cache.dart';
import '../domain/dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._client, this._cache);
  final SupabaseClient _client;
  final JsonCache _cache;

  /// Statistics from the database, or the last synced copy when offline.
  /// If there is no cache (first launch offline) we return a safe empty
  /// dashboard so the screen can render instead of throwing.
  Future<DashboardData> fetch() async {
    try {
      final res = await _client
          .rpc('get_dashboard')
          .timeout(const Duration(seconds: 8));
      await _cache.write(CacheKeys.dashboard, res);
      return DashboardData.fromJson(Map<String, dynamic>.from(res as Map));
    } catch (e) {
      final cached = await _cache.read(CacheKeys.dashboard);
      if (cached is Map) {
        return DashboardData.fromJson(Map<String, dynamic>.from(cached));
      }
      return const DashboardData(
        streakCount: 0,
        longestStreak: 0,
        totalVisits: 0,
        distinctPlaces: 0,
        avgReduction: null,
        bestReduction: null,
        totalMinutes: 0,
        activitiesDone: 0,
        recent: [],
      );
    }
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(
    Supabase.instance.client,
    ref.watch(jsonCacheProvider),
  ),
);

/// ref.invalidate(dashboardProvider) after a visit is finished.
final dashboardProvider = FutureProvider.autoDispose<DashboardData>(
  (ref) => ref.watch(dashboardRepositoryProvider).fetch(),
);
