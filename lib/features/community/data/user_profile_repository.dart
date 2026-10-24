import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/json_cache.dart';
import '../domain/user_profile.dart';

/// Reads and edits Facebook-style profile headers (bio, avatar, cover).
class UserProfileRepository {
  UserProfileRepository(this._client, this._cache);

  final SupabaseClient _client;
  final JsonCache _cache;

  String get currentUserId => _client.auth.currentUser?.id ?? '';

  /// The public header of [userId], or null when the id does not exist.
  /// The last fetched copy is kept on the phone, so a profile that was
  /// opened while online still shows without a connection. If it's the
  /// current user and never cached/offline, fall back to auth metadata.
  Future<UserProfile?> fetchProfile(String userId) async {
    try {
      final res = await _client
          .rpc('get_profile', params: {'p_user_id': userId})
          .timeout(const Duration(seconds: 8));
      if (res == null) return null;
      final map = Map<String, dynamic>.from(res as Map);
      await _cache.write(CacheKeys.userProfile(userId), map);
      return UserProfile.fromJson(map);
    } catch (e) {
      debugPrint('Profile fetch failed, trying cache: $e');
      final cached = await _cache.read(CacheKeys.userProfile(userId));
      if (cached is Map) {
        return UserProfile.fromJson(Map<String, dynamic>.from(cached));
      }

      if (userId == currentUserId) {
        final user = _client.auth.currentUser;
        if (user != null) {
          final meta = user.userMetadata ?? const {};
          final name = meta['full_name'] ??
              meta['name'] ??
              meta['display_name'] ??
              (user.email?.split('@').first) ??
              '';
          final avatar = meta['avatar_url'] ?? meta['picture'];
          final map = <String, dynamic>{
            'id': user.id,
            'full_name': name,
            'avatar_url': avatar,
            'cover_url': null,
            'bio': null,
            'follower_count': 0,
            'following_count': 0,
            'post_count': 0,
            'followed_by_me': false,
            'joined_at': user.createdAt,
          };
          return UserProfile.fromJson(map);
        }
      }
      rethrow;
    }
  }

  /// Saves the name/bio and (when picked) uploads the new photos, then
  /// removes the replaced files. Returns the fresh profile from the server.
  Future<UserProfile?> saveProfile({
    required String name,
    String? bio,
    XFile? avatar,
    XFile? cover,
    String? oldAvatarUrl,
    String? oldCoverUrl,
  }) async {
    final updates = <String, dynamic>{'full_name': name, 'bio': bio};

    String? newAvatarUrl;
    String? newCoverUrl;
    if (avatar != null) newAvatarUrl = await _upload(avatar, 'avatars');
    if (cover != null) newCoverUrl = await _upload(cover, 'covers');
    if (newAvatarUrl != null) updates['avatar_url'] = newAvatarUrl;
    if (newCoverUrl != null) updates['cover_url'] = newCoverUrl;

    await _client.from('profiles').update(updates).eq('id', currentUserId);

    // Best-effort cleanup of the files that are no longer used.
    await _removeReplaced(oldAvatarUrl, newAvatarUrl, 'avatars');
    await _removeReplaced(oldCoverUrl, newCoverUrl, 'covers');

    return fetchProfile(currentUserId);
  }

  /// Uploads one photo into the caller's own folder and returns its
  /// public URL (same pattern as CommunityRepository.createPost).
  Future<String> _upload(XFile file, String bucket) async {
    final isPng = file.name.toLowerCase().endsWith('.png');
    final path =
        '$currentUserId/${DateTime.now().millisecondsSinceEpoch}.${isPng ? 'png' : 'jpg'}';
    final bytes = await file.readAsBytes();
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: isPng ? 'image/png' : 'image/jpeg',
          ),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> _removeReplaced(
      String? oldUrl, String? newUrl, String bucket) async {
    if (oldUrl == null || newUrl == null || oldUrl == newUrl) return;
    final marker = '/object/public/$bucket/';
    final i = oldUrl.indexOf(marker);
    if (i < 0) return;
    try {
      await _client.storage.from(bucket).remove([oldUrl.substring(i + marker.length)]);
    } catch (e) {
      debugPrint('Could not remove old $bucket file: $e');
    }
  }
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepository(
    Supabase.instance.client,
    ref.watch(jsonCacheProvider),
  ),
);

/// The public profile header of [userId] (null when the id is unknown).
/// Call ref.invalidate(userProfileProvider(id)) after editing or following.
final userProfileProvider =
    FutureProvider.autoDispose.family<UserProfile?, String>(
  (ref, userId) => ref.watch(userProfileRepositoryProvider).fetchProfile(userId),
);
