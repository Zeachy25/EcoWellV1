import '../../../core/config.dart';
import '../../map/domain/green_space.dart';
import '../domain/community_models.dart';

String buildPostShareText(FeedPost post) {
  final placeName = post.placeName.trim();
  final title = placeName.isEmpty
      ? 'Post on EcoWell 🌿'
      : '$placeName on EcoWell 🌿';
  return '$title\n$kShareBaseUrl/post/${post.id}';
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
