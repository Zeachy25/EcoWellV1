import 'package:flutter_test/flutter_test.dart';

import 'package:ecowell/core/utils/format.dart';
import 'package:ecowell/features/community/domain/user_profile.dart';

void main() {
  group('UserProfile.fromJson', () {
    test('reads a full get_profile() row', () {
      final p = UserProfile.fromJson({
        'id': 'u-1',
        'full_name': 'Ana Cruz',
        'avatar_url': 'https://cdn/avatars/u-1/a.jpg',
        'cover_url': 'https://cdn/covers/u-1/c.jpg',
        'bio': '  Weekend walker  ',
        'joined_at': '2026-03-05T08:15:00+00:00',
        'follower_count': 128,
        'following_count': 45,
        'post_count': 7,
        'followed_by_me': true,
      });

      expect(p.id, 'u-1');
      expect(p.name, 'Ana Cruz');
      expect(p.avatarUrl, 'https://cdn/avatars/u-1/a.jpg');
      expect(p.coverUrl, 'https://cdn/covers/u-1/c.jpg');
      expect(p.bio, 'Weekend walker'); // trimmed
      expect(p.joinedAt, isNotNull);
      expect(p.joinedAt!.year, 2026);
      expect(p.joinedAt!.month, 3);
      expect(p.followerCount, 128);
      expect(p.followingCount, 45);
      expect(p.postCount, 7);
      expect(p.followedByMe, isTrue);
    });

    test('survives a sparse row (everything optional missing)', () {
      final p = UserProfile.fromJson({'id': 'u-2'});

      expect(p.id, 'u-2');
      expect(p.name, '');
      expect(p.avatarUrl, isNull);
      expect(p.coverUrl, isNull);
      expect(p.bio, isNull);
      expect(p.joinedAt, isNull);
      expect(p.followerCount, 0);
      expect(p.followingCount, 0);
      expect(p.postCount, 0);
      expect(p.followedByMe, isFalse);
    });

    test('treats an empty bio and a bad date as "not set"', () {
      final p = UserProfile.fromJson({
        'id': 'u-3',
        'full_name': 'Sam',
        'bio': '   ',
        'joined_at': 'not-a-date',
      });

      expect(p.bio, isNull);
      expect(p.joinedAt, isNull);
    });

    test('keeps fractional counts as whole numbers', () {
      final p = UserProfile.fromJson({
        'id': 'u-4',
        'follower_count': 12.0,
        'post_count': 3.0,
      });
      expect(p.followerCount, 12);
      expect(p.postCount, 3);
    });
  });

  group('UserProfile.copyWith', () {
    test('applies follow changes but keeps identity and stats', () {
      final p = UserProfile.fromJson({
        'id': 'u-9',
        'full_name': 'Kim Lee',
        'joined_at': '2025-11-01T00:00:00+00:00',
        'follower_count': 10,
        'following_count': 4,
        'post_count': 6,
        'followed_by_me': false,
      });

      final followed = p.copyWith(followedByMe: true, followerCount: 11);

      expect(followed.followedByMe, isTrue);
      expect(followed.followerCount, 11);
      expect(followed.id, 'u-9');
      expect(followed.name, 'Kim Lee');
      expect(followed.followingCount, 4);
      expect(followed.postCount, 6);
      expect(followed.joinedAt, p.joinedAt);

      final unfollowed = followed.copyWith(followedByMe: false);
      expect(unfollowed.followedByMe, isFalse);
      expect(unfollowed.followerCount, 11); // copyWith does not decrement
    });
  });

  group('formatMonthYear', () {
    test('renders the profile Joined date in full', () {
      expect(formatMonthYear(DateTime(2026, 10, 20)), 'October 2026');
      expect(formatMonthYear(DateTime(2025, 1, 3)), 'January 2025');
    });
  });
}
