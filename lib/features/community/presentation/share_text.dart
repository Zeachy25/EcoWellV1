import '../../map/domain/green_space.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';

String buildPostShareText(
  FeedPost post, {
  String Function(String path)? resolvePhotoUrl,
}) {
  final caption = (post.caption ?? '').trim();
  final address = (post.placeAddress ?? '').trim();
  final photo = post.photoPaths.isEmpty
      ? null
      : (resolvePhotoUrl ?? CommunityRepository.photoUrl)(
          post.photoPaths.first,
        );

  final lines = <String>[
    '${post.author.name} on EcoWell',
    '${post.placeName}${address.isEmpty ? '' : ' · $address'}',
    if (caption.isNotEmpty) caption,
    if (photo != null && photo.trim().isNotEmpty) 'Photo: $photo',
    'Shared from EcoWell.',
  ];

  return lines.join('\n\n');
}

String buildPlaceShareText(GreenSpace place) {
  final address = (place.address ?? '').trim();
  final description = (place.description ?? '').trim();
  final photo = (place.photoUrl ?? '').trim();
  final score = place.quietScoreAvg;

  final lines = <String>[
    '${place.name} · ${place.categoryLabel}',
    if (address.isNotEmpty) address,
    if (score != null) 'Quiet Score: ${score.toStringAsFixed(1)}',
    if (description.isNotEmpty) description,
    if (photo.isNotEmpty) 'Photo: $photo',
    'Map: https://www.google.com/maps/search/?api=1&query=${place.lat},${place.lng}',
    'Shared from EcoWell.',
  ];

  return lines.join('\n\n');
}
