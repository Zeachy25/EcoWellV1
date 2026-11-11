import 'package:flutter_test/flutter_test.dart';

import 'package:ecowell/features/community/domain/community_models.dart';

void main() {
  test('PlaceComment reads public author name and avatar', () {
    final comment = PlaceComment.fromJson({
      'id': 'comment-1',
      'user_id': 'user-1',
      'body': 'A peaceful place.',
      'created_at': '2026-10-27T13:15:57.452823Z',
      'author': {
        'full_name': 'Reyan Ryn Olivar',
        'avatar_url': 'https://example.com/avatar.jpg',
      },
    });

    expect(comment.userId, 'user-1');
    expect(comment.authorName, 'Reyan Ryn Olivar');
    expect(comment.authorAvatar, 'https://example.com/avatar.jpg');
  });

  test('PlaceComment keeps a fallback when public author is unavailable', () {
    final comment = PlaceComment.fromJson({
      'id': 'comment-2',
      'user_id': 'user-2',
      'body': 'A peaceful place.',
      'created_at': '2026-10-27T13:15:57.452823Z',
      'author': null,
    });

    expect(comment.authorName, 'EcoWell user');
    expect(comment.authorAvatar, isNull);
  });
}
