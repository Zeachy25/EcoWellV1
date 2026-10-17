import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config.dart';

/// The signed-in user's profile row. Call ref.invalidate(profileProvider)
/// after something changes it (for example after finishing a visit).
final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async {
    return await supabase
        .from('profiles')
        .select('full_name, avatar_url, streak_count, birthdate, consented_at')
        .single();
  },
);
