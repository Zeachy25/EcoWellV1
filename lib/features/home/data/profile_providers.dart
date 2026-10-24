import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';
import '../../../core/offline/json_cache.dart';

/// The signed-in user's profile row. Call ref.invalidate(profileProvider)
/// after something changes it (for example after finishing a visit).
///
/// Falls back to the last synced copy when the phone is offline, so Home
/// can still greet the user and show their streak. If there's never been a
/// cached copy (e.g. first launch offline), we fall back to the auth user
/// metadata so the header still renders.
final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async {
    final cache = ref.watch(jsonCacheProvider);
    try {
      final row = await supabase
          .from('profiles')
          .select('id, full_name, avatar_url, streak_count, birthdate, consented_at')
          .single()
          // With no connection, fail after 8 seconds so the screen can show
          // the saved copy instead of waiting forever.
          .timeout(const Duration(seconds: 8));
      await cache.write(CacheKeys.profile, row);
      return row;
    } catch (e) {
      final cached = await cache.read(CacheKeys.profile);
      if (cached is Map) return Map<String, dynamic>.from(cached);

      final user = supabase.auth.currentUser;
      if (user != null) {
        final meta = user.userMetadata ?? const {};
        final name = meta['full_name'] ??
            meta['name'] ??
            meta['display_name'] ??
            (user.email?.split('@').first);
        final avatar = meta['avatar_url'] ?? meta['picture'];
        return <String, dynamic>{
          'id': user.id,
          'full_name': name,
          'avatar_url': avatar,
          'streak_count': 0,
          'birthdate': null,
          'consented_at': null,
        };
      }
      rethrow;
    }
  },
);
