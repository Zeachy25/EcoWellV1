import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/community_models.dart';

class CommunityRepository {
  CommunityRepository(this._client);
  final SupabaseClient _client;

  static const _bucket = 'post-media';

  String get currentUserId => _client.auth.currentUser?.id ?? '';

  /// Public link of a photo stored in the post-media bucket.
  static String photoUrl(String path) => Supabase.instance.client.storage
      .from(_bucket)
      .getPublicUrl(path);

  // ---- feed ----------------------------------------------------------------

  Future<List<FeedPost>> fetchFeed({
    DateTime? before,
    bool followingOnly = false,
    int limit = 20,
  }) async {
    final res = await _client.rpc('get_feed', params: {
      'p_limit': limit,
      'p_before': before?.toUtc().toIso8601String(),
      'p_following_only': followingOnly,
    });
    return [
      for (final r in (res as List<dynamic>))
        FeedPost.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  // ---- posting ---------------------------------------------------------------

  /// Uploads the photos, then saves the post. If saving fails, the uploaded
  /// photos are removed again.
  Future<void> createPost({
    required String placeId,
    required String caption,
    required List<XFile> photos,
    String? visitId,
  }) async {
    final uid = currentUserId;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final uploaded = <String>[];
    try {
      for (var i = 0; i < photos.length; i++) {
        final isPng = photos[i].name.toLowerCase().endsWith('.png');
        final path = '$uid/${stamp}_$i.${isPng ? 'png' : 'jpg'}';
        final bytes = await photos[i].readAsBytes();
        await _client.storage.from(_bucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: isPng ? 'image/png' : 'image/jpeg',
              ),
            );
        uploaded.add(path);
      }
      await _client.rpc('create_post', params: {
        'p_place_id': placeId,
        'p_caption': caption,
        'p_photo_paths': uploaded,
        'p_visit_id': visitId,
      });
    } catch (e) {
      if (uploaded.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove(uploaded);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> deletePost(FeedPost post) async {
    await _client.from('posts').delete().eq('id', post.id);
    try {
      await _client.storage.from(_bucket).remove(post.photoPaths);
    } catch (_) {
      // The post is gone; leftover files are not shown anywhere.
    }
  }

  Future<void> reportPost(String postId, String reason) async {
    await _client.from('post_reports').insert({
      'post_id': postId,
      'reporter_id': currentUserId,
      'reason': reason,
    });
  }

  /// The user's latest finished visit at this place, or null.
  Future<VisitStats?> latestVisitAt(String placeId) async {
    final rows = await _client
        .from('visit_summaries')
        .select('visit_id, entry_time, exit_time, stress_reduction_score')
        .eq('place_id', placeId)
        .eq('status', 'completed')
        .order('entry_time', ascending: false)
        .limit(1) as List<dynamic>;
    if (rows.isEmpty) return null;
    final r = Map<String, dynamic>.from(rows.first as Map);
    final exit = r['exit_time'] as String?;
    if (exit == null) return null;
    final minutes = DateTime.parse(exit)
        .difference(DateTime.parse(r['entry_time'] as String))
        .inMinutes;
    return VisitStats(
      visitId: r['visit_id'] as String,
      minutes: minutes,
      reduction: (r['stress_reduction_score'] as num?)?.toInt() ?? 0,
    );
  }

  // ---- likes and comments ------------------------------------------------------

  Future<void> setLike(String postId, bool like) async {
    if (like) {
      await _client.from('post_likes').upsert(
        {'post_id': postId, 'user_id': currentUserId},
        onConflict: 'post_id,user_id',
        ignoreDuplicates: true,
      );
    } else {
      await _client
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', currentUserId);
    }
  }

  Future<List<PostComment>> fetchComments(String postId) async {
    final res = await _client.rpc('get_comments', params: {'p_post_id': postId});
    return [
      for (final r in (res as List<dynamic>))
        PostComment.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<void> addComment(String postId, String body) async {
    await _client.from('post_comments').insert({
      'post_id': postId,
      'user_id': currentUserId,
      'body': body.trim(),
    });
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('post_comments').delete().eq('id', commentId);
  }

  // ---- My Day ------------------------------------------------------------------

  /// Active My Days of you and the people you follow, grouped per person:
  /// yours first, then people with unseen photos, then the rest.
  Future<List<MyDayStory>> fetchMyDayStories() async {
    final res = await _client.rpc('get_my_day_items');
    final byUser = <String, List<MyDayItem>>{};
    for (final r in (res as List<dynamic>)) {
      final item = MyDayItem.fromJson(Map<String, dynamic>.from(r as Map));
      byUser.putIfAbsent(item.userId, () => []).add(item);
    }
    final stories = [
      for (final e in byUser.entries)
        MyDayStory(
          userId: e.key,
          name: e.value.first.authorName,
          avatarUrl: e.value.first.authorAvatar,
          items: e.value,
        ),
    ];
    final me = currentUserId;
    int rank(MyDayStory s) => s.userId == me ? 0 : (s.hasUnseen ? 1 : 2);
    stories.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : b.latest.compareTo(a.latest);
    });
    return stories;
  }

  /// Uploads the photo, then saves the My Day. Removes the photo again if
  /// saving fails.
  Future<void> createMyDay({
    required String placeId,
    required String placeName,
    required String caption,
    required XFile photo,
    int? visitMinutes,
    int? stressReduction,
  }) async {
    final isPng = photo.name.toLowerCase().endsWith('.png');
    final path = '$currentUserId/myday_'
        '${DateTime.now().millisecondsSinceEpoch}.${isPng ? 'png' : 'jpg'}';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          await photo.readAsBytes(),
          fileOptions: FileOptions(
            contentType: isPng ? 'image/png' : 'image/jpeg',
          ),
        );
    try {
      final text = caption.trim();
      await _client.from('my_days').insert({
        'photo_path': path,
        'caption': text.isEmpty ? null : text,
        'place_id': placeId,
        'place_name': placeName,
        'visit_minutes': visitMinutes,
        'stress_reduction': stressReduction,
      });
    } catch (e) {
      try {
        await _client.storage.from(_bucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> markMyDayViewed(String myDayId) async {
    await _client.from('my_day_views').upsert(
      {'my_day_id': myDayId, 'viewer_id': currentUserId},
      onConflict: 'my_day_id,viewer_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> deleteMyDay(MyDayItem item) async {
    await _client.from('my_days').delete().eq('id', item.id);
    try {
      await _client.storage.from(_bucket).remove([item.photoPath]);
    } catch (_) {
      // The row is gone; a leftover file is not shown anywhere.
    }
  }

  // ---- people --------------------------------------------------------------------

  Future<List<SuggestedUser>> fetchSuggested({int limit = 10}) async {
    final res =
        await _client.rpc('get_suggested_users', params: {'p_limit': limit});
    return [
      for (final r in (res as List<dynamic>))
        SuggestedUser.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<void> setFollow(String userId, bool follow) async {
    if (follow) {
      await _client.from('follows').upsert(
        {'follower_id': currentUserId, 'following_id': userId},
        onConflict: 'follower_id,following_id',
        ignoreDuplicates: true,
      );
    } else {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('following_id', userId);
    }
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(Supabase.instance.client),
);