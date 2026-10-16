import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._client);
  final SupabaseClient _client;

  Future<DashboardData> fetch() async {
    final res = await _client.rpc('get_dashboard');
    return DashboardData.fromJson(Map<String, dynamic>.from(res as Map));
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(Supabase.instance.client),
);

/// ref.invalidate(dashboardProvider) after a visit is finished.
final dashboardProvider = FutureProvider.autoDispose<DashboardData>(
  (ref) => ref.watch(dashboardRepositoryProvider).fetch(),
);
