import 'package:flutter_test/flutter_test.dart';
import 'package:ecowell/features/community/domain/community_models.dart';

void main() {
  test(
    'PlaceSocial cache data preserves counts and current-user like state',
    () {
      const social = PlaceSocial(
        placeId: 'park-1',
        likeCount: 2,
        commentCount: 1,
        likedByMe: true,
      );

      final restored = PlaceSocial.fromJson(social.toJson());

      expect(restored.placeId, 'park-1');
      expect(restored.likeCount, 2);
      expect(restored.commentCount, 1);
      expect(restored.likedByMe, isTrue);
    },
  );
}
