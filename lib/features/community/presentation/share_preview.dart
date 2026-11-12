import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/full_screen_image_viewer.dart';
import '../../map/domain/green_space.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'post_image_collage.dart';
import 'user_avatar.dart';

class PostSharePreview extends StatelessWidget {
  const PostSharePreview({
    super.key,
    required this.post,
    required this.heroPrefix,
  });

  final FeedPost post;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final urls = [
      for (final path in post.photoPaths) CommunityRepository.photoUrl(path),
    ];
    final caption = (post.caption ?? '').trim();
    final address = (post.placeAddress ?? '').trim();
    final placeLine = address.isEmpty
        ? post.placeName
        : '${post.placeName} · $address';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Responsive.radius(context, 14)),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                UserAvatar(
                  name: post.author.name,
                  url: post.author.avatarUrl,
                  radius: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: Responsive.fontSize(context, 14),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        placeLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: Responsive.fontSize(context, 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                caption,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: Responsive.fontSize(context, 14),
                  height: 1.35,
                ),
              ),
            ),
          if (urls.isNotEmpty)
            PostImageCollage(
              imageUrls: urls,
              postId: heroPrefix,
              onImageTap: (index) {
                Navigator.of(context, rootNavigator: true).push(
                  FullScreenImageViewer.route(
                    imageUrls: urls,
                    initialIndex: index,
                    heroTagPrefix: heroPrefix,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class PlaceSharePreview extends StatelessWidget {
  const PlaceSharePreview({super.key, required this.place, this.onTap});

  final GreenSpace place;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final photo = (place.photoUrl ?? '').trim();
    final address = (place.address ?? '').trim();
    final description = (place.description ?? '').trim();
    final score = place.quietScoreAvg;
    final meta = address.isEmpty
        ? place.categoryLabel
        : '${place.categoryLabel} · $address';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Responsive.radius(context, 14)),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (photo.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 150,
                  child: CachedNetworkImage(
                    imageUrl: photo,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const ColoredBox(color: AppColors.surfaceMuted),
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: AppColors.surfaceMuted,
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 92,
                  color: AppColors.mintLight,
                  child: const Center(
                    child: Icon(
                      Icons.park_outlined,
                      size: 34,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            place.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: Responsive.fontSize(context, 16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (score != null) ...[
                          const SizedBox(width: 8),
                          _ScoreBadge(score: score),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: Responsive.fontSize(context, 12),
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: Responsive.fontSize(context, 13),
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (onTap != null) ...[
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View place',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors.primaryGreen,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UnavailableShareCard extends StatelessWidget {
  const UnavailableShareCard({
    super.key,
    this.message = 'Original post unavailable',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(Responsive.radius(context, 14)),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_off, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: Responsive.fontSize(context, 13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mintLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.spa_outlined,
            size: 14,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 4),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              color: AppColors.primaryGreen,
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
