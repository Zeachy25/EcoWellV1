import 'package:flutter_test/flutter_test.dart';

import 'package:ecowell/core/offline/json_cache.dart';
import 'package:ecowell/features/community/domain/community_models.dart';

void main() {
  test('FollowedUser cache data round-trips public profile fields', () {
    const user = FollowedUser(
      id: 'user-1',
      name: 'Ana Cruz',
      avatarUrl: 'https://example.com/avatar.jpg',
    );

    final restored = FollowedUser.fromJson(user.toJson());

    expect(
      user.toJson(),
      {
        'user_id': 'user-1',
        'full_name': 'Ana Cruz',
        'avatar_url': 'https://example.com/avatar.jpg',
      },
    );
    expect(restored.id, user.id);
    expect(restored.name, user.name);
    expect(restored.avatarUrl, user.avatarUrl);
  });

  test('following cache keys are scoped to the signed-in account', () {
    expect(
      CacheKeys.followingProfiles('account-1'),
      'following_profiles:account-1',
    );
    expect(
      CacheKeys.followingProfiles('account-1'),
      isNot(CacheKeys.followingProfiles('account-2')),
    );
  });
}
