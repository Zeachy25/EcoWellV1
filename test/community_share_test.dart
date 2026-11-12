import 'package:ecowell/core/config.dart';
import 'package:ecowell/features/community/domain/community_models.dart';
import 'package:ecowell/features/community/presentation/share_text.dart';
import 'package:ecowell/features/map/domain/green_space.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _postJson({
  String id = 'p-1',
  String? caption,
  String placeName = 'Riverside Park',
  List<String> photos = const [],
  String? sharedPostId,
  Map<String, dynamic>? sharedPost,
  String? sharedPlaceId,
  Map<String, dynamic>? sharedPlace,
}) {
  return {
    'id': id,
    'caption': caption,
    'created_at': '2026-01-01T00:00:00Z',
    'author': {
      'id': 'u-1',
      'name': 'Ana Cruz',
      'avatar_url': 'https://cdn/avatars/u-1.jpg',
    },
    'place_id': 'g-1',
    'place_name': placeName,
    'place_address': 'Main Street',
    'place_score': 4.5,
    'photos': photos,
    'like_count': 0,
    'comment_count': 0,
    'liked_by_me': false,
    'likers': <Map<String, dynamic>>[],
    'visit_minutes': null,
    'stress_reduction': null,
    'shared_post_id': sharedPostId,
    'shared_place_id': sharedPlaceId,
    'shared_post': sharedPost,
    'shared_place': sharedPlace,
  };
}

Map<String, dynamic> _placeJson() {
  return {
    'id': 'g-1',
    'name': 'Riverside Park',
    'description': 'A calm place by the water.',
    'category': 'park',
    'address': 'Main Street',
    'photo_url': 'https://cdn/places/riverside.jpg',
    'lat': 1.5,
    'lng': 2.5,
    'boundary_geojson': null,
    'quiet_score_avg': 4.2,
    'quiet_rating_count': 8,
  };
}

void main() {
  group('FeedPost sharing', () {
    test('parses an available shared post', () {
      final original = _postJson(id: 'original', caption: 'A walk');
      final share = FeedPost.fromJson(
        _postJson(
          id: 'share-1',
          caption: 'Look at this',
          sharedPostId: 'original',
          sharedPost: original,
        ),
      );

      expect(share.isShare, isTrue);
      expect(share.sharedPostId, 'original');
      expect(share.sharedPost?.id, 'original');
      expect(share.sharedPost?.caption, 'A walk');
      expect(share.isShareUnavailable, isFalse);
    });

    test('marks a share unavailable when the original is missing', () {
      final share = FeedPost.fromJson(
        _postJson(id: 'share-2', sharedPostId: 'deleted-post'),
      );

      expect(share.isShare, isTrue);
      expect(share.sharedPost, isNull);
      expect(share.isShareUnavailable, isTrue);
    });

    test('parses an available shared place', () {
      final share = FeedPost.fromJson(
        _postJson(
          id: 'share-3',
          sharedPlaceId: 'g-1',
          sharedPlace: _placeJson(),
        ),
      );

      expect(share.isShare, isTrue);
      expect(share.sharedPlace?.name, 'Riverside Park');
      expect(share.sharedPlace?.quietScoreAvg, 4.2);
      expect(share.isShareUnavailable, isFalse);
    });

    test('marks a place share unavailable when the place is missing', () {
      final share = FeedPost.fromJson(
        _postJson(id: 'share-4', sharedPlaceId: 'deleted-place'),
      );

      expect(share.isShare, isTrue);
      expect(share.isShareUnavailable, isTrue);
    });

    test('copyWith keeps share fields', () {
      final share = FeedPost.fromJson(
        _postJson(
          id: 'share-5',
          sharedPlaceId: 'g-1',
          sharedPlace: _placeJson(),
        ),
      );

      final updated = share.copyWith(likeCount: 7);

      expect(updated.likeCount, 7);
      expect(updated.sharedPlaceId, 'g-1');
      expect(updated.sharedPlace?.id, 'g-1');
    });
  });

  group('share text', () {
    test('post text is the place title plus the public link', () {
      final post = FeedPost.fromJson(
        _postJson(caption: 'Morning walk', photos: ['u-1/photo.jpg']),
      );

      final text = buildPostShareText(post);

      expect(
        text,
        'Riverside Park on EcoWell 🌿\n$kShareBaseUrl/post/p-1',
      );
      expect(text.split('\n'), hasLength(2));
    });

    test('post text falls back when the place name is empty', () {
      final post = FeedPost.fromJson(_postJson(placeName: ''));

      final text = buildPostShareText(post);

      expect(text, 'Post on EcoWell 🌿\n$kShareBaseUrl/post/p-1');
    });

    test('place text includes score, photo, and map link', () {
      const place = GreenSpace(
        id: 'g-1',
        name: 'Riverside Park',
        lat: 1.5,
        lng: 2.5,
        boundary: [],
        description: 'A calm place by the water.',
        category: 'park',
        address: 'Main Street',
        photoUrl: 'https://cdn/places/riverside.jpg',
        quietScoreAvg: 4.2,
        quietRatingCount: 8,
      );

      final text = buildPlaceShareText(place);

      expect(text, contains('Riverside Park · Park'));
      expect(text, contains('Quiet Score: 4.2'));
      expect(text, contains('https://cdn/places/riverside.jpg'));
      expect(
        text,
        contains('https://www.google.com/maps/search/?api=1&query=1.5,2.5'),
      );
    });
  });
}
