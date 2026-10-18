class PostAuthor {
  const PostAuthor({required this.id, required this.name, this.avatarUrl});

  final String id;
  final String name;
  final String? avatarUrl;

  factory PostAuthor.fromJson(Map<String, dynamic> j) {
    final raw = ((j['name'] as String?) ?? '').trim();
    return PostAuthor(
      id: (j['id'] as String?) ?? '',
      name: raw.isEmpty ? 'EcoWell user' : raw,
      avatarUrl: j['avatar_url'] as String?,
    );
  }
}

class Liker {
  const Liker({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  factory Liker.fromJson(Map<String, dynamic> j) {
    final raw = ((j['name'] as String?) ?? '').trim();
    return Liker(
      name: raw.isEmpty ? 'Someone' : raw,
      avatarUrl: j['avatar_url'] as String?,
    );
  }
}

class FeedPost {
  const FeedPost({
    required this.id,
    required this.createdAt,
    required this.author,
    required this.placeId,
    required this.placeName,
    required this.photoPaths,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.likers,
    this.caption,
    this.placeAddress,
    this.placeScore,
    this.visitMinutes,
    this.stressReduction,
  });

  final String id;
  final String? caption;
  final DateTime createdAt;
  final PostAuthor author;
  final String placeId;
  final String placeName;
  final String? placeAddress;
  final double? placeScore;

  /// Paths inside the "post-media" storage bucket.
  final List<String> photoPaths;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final List<Liker> likers;

  /// Copied from the poster's visit when they chose to include it.
  final int? visitMinutes;
  final int? stressReduction;

  bool get hasVisitStats => visitMinutes != null || stressReduction != null;

  FeedPost copyWith({int? likeCount, int? commentCount, bool? likedByMe}) {
    return FeedPost(
      id: id,
      createdAt: createdAt,
      author: author,
      placeId: placeId,
      placeName: placeName,
      photoPaths: photoPaths,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
      likers: likers,
      caption: caption,
      placeAddress: placeAddress,
      placeScore: placeScore,
      visitMinutes: visitMinutes,
      stressReduction: stressReduction,
    );
  }

  factory FeedPost.fromJson(Map<String, dynamic> j) {
    return FeedPost(
      id: j['id'] as String,
      caption: j['caption'] as String?,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      author: PostAuthor.fromJson(Map<String, dynamic>.from(j['author'] as Map)),
      placeId: (j['place_id'] as String?) ?? '',
      placeName: (j['place_name'] as String?) ?? 'Green space',
      placeAddress: j['place_address'] as String?,
      placeScore: (j['place_score'] as num?)?.toDouble(),
      photoPaths: [
        for (final p in (j['photos'] as List<dynamic>? ?? const [])) p as String,
      ],
      likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
      likedByMe: (j['liked_by_me'] as bool?) ?? false,
      likers: [
        for (final l in (j['likers'] as List<dynamic>? ?? const []))
          Liker.fromJson(Map<String, dynamic>.from(l as Map)),
      ],
      visitMinutes: (j['visit_minutes'] as num?)?.toInt(),
      stressReduction: (j['stress_reduction'] as num?)?.toInt(),
    );
  }
}

class PostComment {
  const PostComment({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.authorAvatar,
  });

  final String id;
  final String userId;
  final String authorName;
  final String? authorAvatar;
  final String body;
  final DateTime createdAt;

  factory PostComment.fromJson(Map<String, dynamic> j) {
    final raw = ((j['author_name'] as String?) ?? '').trim();
    return PostComment(
      id: j['id'] as String,
      userId: (j['user_id'] as String?) ?? '',
      authorName: raw.isEmpty ? 'EcoWell user' : raw,
      authorAvatar: j['author_avatar'] as String?,
      body: (j['body'] as String?) ?? '',
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
    );
  }
}

class SuggestedUser {
  const SuggestedUser({
    required this.id,
    required this.name,
    required this.followers,
    this.avatarUrl,
    this.following = false,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final int followers;
  final bool following;

  SuggestedUser copyWith({bool? following, int? followers}) => SuggestedUser(
        id: id,
        name: name,
        avatarUrl: avatarUrl,
        followers: followers ?? this.followers,
        following: following ?? this.following,
      );

  factory SuggestedUser.fromJson(Map<String, dynamic> j) {
    final raw = ((j['name'] as String?) ?? '').trim();
    return SuggestedUser(
      id: j['id'] as String,
      name: raw.isEmpty ? 'EcoWell user' : raw,
      avatarUrl: j['avatar_url'] as String?,
      followers: (j['followers'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The poster's latest finished visit at a place (offered when posting).
class VisitStats {
  const VisitStats({
    required this.visitId,
    required this.minutes,
    required this.reduction,
  });

  final String visitId;
  final int minutes;
  final int reduction;
}

/// One My Day photo (lasts 24 hours, shown only in the story row).
class MyDayItem {
  const MyDayItem({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.photoPath,
    required this.placeName,
    required this.createdAt,
    required this.expiresAt,
    required this.viewedByMe,
    required this.viewCount,
    this.authorAvatar,
    this.caption,
    this.visitMinutes,
    this.stressReduction,
  });

  final String id;
  final String userId;
  final String authorName;
  final String? authorAvatar;

  /// Path inside the "post-media" storage bucket.
  final String photoPath;
  final String? caption;
  final String placeName;
  final int? visitMinutes;
  final int? stressReduction;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool viewedByMe;

  /// Only filled in for your own My Days.
  final int viewCount;

  factory MyDayItem.fromJson(Map<String, dynamic> j) {
    final raw = ((j['author_name'] as String?) ?? '').trim();
    return MyDayItem(
      id: j['id'] as String,
      userId: (j['user_id'] as String?) ?? '',
      authorName: raw.isEmpty ? 'EcoWell user' : raw,
      authorAvatar: j['author_avatar'] as String?,
      photoPath: j['photo_path'] as String,
      caption: j['caption'] as String?,
      placeName: (j['place_name'] as String?) ?? 'Green space',
      visitMinutes: (j['visit_minutes'] as num?)?.toInt(),
      stressReduction: (j['stress_reduction'] as num?)?.toInt(),
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      expiresAt: DateTime.parse(j['expires_at'] as String).toLocal(),
      viewedByMe: (j['viewed_by_me'] as bool?) ?? false,
      viewCount: (j['view_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// All active My Day photos of one person, oldest first.
class MyDayStory {
  const MyDayStory({
    required this.userId,
    required this.name,
    required this.items,
    this.avatarUrl,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final List<MyDayItem> items;

  bool get hasUnseen => items.any((i) => !i.viewedByMe);
  DateTime get latest => items.last.createdAt;
}