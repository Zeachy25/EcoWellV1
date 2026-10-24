/// The public header of any EcoWell profile, exactly what get_profile()
/// returns: what everyone may see. Wellness data (streak, stress scores)
/// is deliberately never part of it.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    this.joinedAt,
    required this.followerCount,
    required this.followingCount,
    required this.postCount,
    required this.followedByMe,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final String? coverUrl;

  /// Short "about me" text; empty or missing shows the add-a-bio prompt.
  final String? bio;

  /// When the account was created ("Joined October 2026"), if known.
  final DateTime? joinedAt;

  final int followerCount;
  final int followingCount;
  final int postCount;
  final bool followedByMe;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final bio = json['bio'] as String?;
    final joined = json['joined_at'] as String?;
    return UserProfile(
      id: json['id'] as String? ?? '',
      name: json['full_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      bio: bio == null || bio.trim().isEmpty ? null : bio.trim(),
      joinedAt: joined == null ? null : DateTime.tryParse(joined)?.toLocal(),
      followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      postCount: (json['post_count'] as num?)?.toInt() ?? 0,
      followedByMe: json['followed_by_me'] as bool? ?? false,
    );
  }

  UserProfile copyWith({
    String? name,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
    int? followerCount,
    bool? followedByMe,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      bio: bio ?? this.bio,
      joinedAt: joinedAt,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount,
      postCount: postCount,
      followedByMe: followedByMe ?? this.followedByMe,
    );
  }
}
