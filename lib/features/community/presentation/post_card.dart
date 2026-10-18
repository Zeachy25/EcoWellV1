import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'user_avatar.dart';

enum PostMenuAction { delete, report }

/// One post in the Explore feed, top to bottom:
/// avatar + name (rating on the right) / date and time / location, caption, (visit chips),
/// photo, likes + comments summary, then a Heart | Comment | Share bar.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.isMine,
    required this.onLike,
    required this.onComments,
    required this.onShare,
    required this.onMenu,
  });

  final FeedPost post;
  final bool isMine;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final ValueChanged<PostMenuAction> onMenu;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _page = 0;

  /// "October 19, 2024 at 4:05 PM"
  String _when(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${months[d.month - 1]} ${d.day}, ${d.year} at $hour:$minute $ampm';
  }

  Widget _photoBox(String path) {
    final placeholder = Container(
      color: AppColors.cardBorder,
      child: const Center(
        child:
            Icon(Icons.image_outlined, size: 48, color: AppColors.textTertiary),
      ),
    );
    return Image.network(
      CommunityRepository.photoUrl(path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : Container(
              color: AppColors.cardBorder,
              child: const Center(child: CircularProgressIndicator()),
            ),
    );
  }

  /// Small chips: visit time and stress change (only what exists).
  Widget _chips(FeedPost p) {
    final chips = <Widget>[];

    if (p.visitMinutes != null) {
      chips.add(_Chip(
        icon: Icons.timer_outlined,
        text: formatDuration(p.visitMinutes! * 60.0),
        color: AppColors.forestMid,
      ));
    }
    final r = p.stressReduction;
    if (r != null) {
      if (r > 0) {
        chips.add(_Chip(
          icon: Icons.trending_down_rounded,
          text: 'Stress \u2212$r',
          color: AppColors.forestMid,
          filled: true,
        ));
      } else if (r < 0) {
        chips.add(_Chip(
          icon: Icons.trending_up_rounded,
          text: 'Stress +${-r}',
          color: AppColors.streakOrange,
        ));
      } else {
        chips.add(const _Chip(
          icon: Icons.remove_rounded,
          text: 'Stress unchanged',
          color: AppColors.textSecondary,
        ));
      }
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          Responsive.size(context, 14), 12, Responsive.size(context, 14), 0),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final radius = Responsive.radius(context, 18);
    final pad = Responsive.size(context, 14);
    final hasCaption = p.caption != null && p.caption!.isNotEmpty;
    final hasAddress = p.placeAddress != null && p.placeAddress!.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: Responsive.size(context, 16)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: avatar | name / date and time / location | menu ──
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad - 2, pad, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(
                    name: p.author.name,
                    url: p.author.avatarUrl,
                    radius: 20,
                    ring: true,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: Responsive.fontSize(context, 15),
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _when(p.createdAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: Responsive.fontSize(context, 12),
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 14, color: AppColors.mintGreen),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: p.placeName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (hasAddress)
                                      TextSpan(
                                        text: ' \u00b7 ${p.placeAddress}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Right side: rating in the top-right corner, menu below it.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (p.placeScore != null)
                        _RatingBadge(score: p.placeScore!)
                      else
                        const SizedBox(height: 22),
                      const SizedBox(height: 4), // move the menu up/down here
                      PopupMenuButton<PostMenuAction>(
                    tooltip: 'More',
                    padding: EdgeInsets.zero,
                    child: const SizedBox(
                      width: 28,
                      height: 32,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Icon(Icons.more_horiz,
                            size: 22, color: AppColors.textSecondary),
                      ),
                    ),
                    onSelected: widget.onMenu,
                    itemBuilder: (_) => [
                      if (widget.isMine)
                        const PopupMenuItem(
                          value: PostMenuAction.delete,
                          child: Text('Delete post'),
                        )
                      else
                        const PopupMenuItem(
                          value: PostMenuAction.report,
                          child: Text('Report post'),
                        ),
                    ],
                  ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Caption ──
            if (hasCaption)
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                child: Text(
                  p.caption!,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 14),
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

            // ── Visit chips (time, stress, rating) ──
            _chips(p),

            // ── Photo (edge to edge) ──
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (p.photoPaths.isEmpty)
                    Container(color: AppColors.cardBorder)
                  else
                    PageView.builder(
                      itemCount: p.photoPaths.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => _photoBox(p.photoPaths[i]),
                    ),
                  if (p.photoPaths.length > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < p.photoPaths.length; i++)
                              Container(
                                width: 7,
                                height: 7,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == _page
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Likes (left) and comments (right) ──
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 10, pad, 10),
              child: Row(
                children: [
                  if (p.likers.isNotEmpty)
                    SizedBox(
                      width: 15.0 * p.likers.length + 9,
                      height: 24,
                      child: Stack(
                        children: [
                          for (var i = 0; i < p.likers.length; i++)
                            Positioned(
                              left: 15.0 * i,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.surface,
                                child: UserAvatar(
                                  name: p.likers[i].name,
                                  url: p.likers[i].avatarUrl,
                                  radius: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (p.likers.isNotEmpty) const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      p.likeCount == 0
                          ? 'Be the first to like this'
                          : '${formatCount(p.likeCount)} '
                              '${p.likeCount == 1 ? 'like' : 'likes'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onComments,
                    child: Text(
                      '${formatCount(p.commentCount)} '
                      '${p.commentCount == 1 ? 'comment' : 'comments'}',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 12),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Heart | Comment | Share ──
            const Divider(height: 1, color: AppColors.cardBorder),
            IntrinsicHeight(
              child: Row(
                children: [
                  _BarButton(
                    tooltip: 'Like',
                    icon: p.likedByMe ? Icons.favorite : Icons.favorite_border,
                    color: p.likedByMe
                        ? Colors.redAccent
                        : AppColors.textPrimary,
                    onTap: widget.onLike,
                  ),
                  const VerticalDivider(
                      width: 1, thickness: 1, color: AppColors.cardBorder),
                  _BarButton(
                    tooltip: 'Comments',
                    icon: Icons.chat_bubble_outline,
                    color: AppColors.textPrimary,
                    onTap: widget.onComments,
                  ),
                  const VerticalDivider(
                      width: 1, thickness: 1, color: AppColors.cardBorder),
                  _BarButton(
                    tooltip: 'Share',
                    icon: Icons.ios_share,
                    color: AppColors.textPrimary,
                    onTap: widget.onShare,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Icon(icon, size: 24, color: color),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.text,
    required this.color,
    this.filled = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB300)),
          const SizedBox(width: 3),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}