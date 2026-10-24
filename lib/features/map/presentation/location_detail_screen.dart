import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/background_pattern.dart';
import '../../community/data/community_repository.dart';
import '../../community/domain/community_models.dart';
import '../../community/presentation/place_comments_sheet.dart';
import '../../community/presentation/user_avatar.dart';
import '../domain/geo_utils.dart';
import '../domain/green_space.dart';

class LocationDetailScreen extends ConsumerStatefulWidget {
  const LocationDetailScreen({super.key, required this.space});

  final GreenSpace space;

  @override
  ConsumerState<LocationDetailScreen> createState() =>
      _LocationDetailScreenState();
}

class _LocationDetailScreenState extends ConsumerState<LocationDetailScreen> {
  Map<String, PlaceSocial> _allSocial = {};
  List<PlaceComment> _comments = [];
  bool _commentsLoading = true;
  bool _commentsFailed = false;
  bool _socialFailed = false;
  bool _liking = false;
  bool _checkingLocation = false;

  CommunityRepository get _community => ref.read(communityRepositoryProvider);

  PlaceSocial get _social =>
      _allSocial[widget.space.id] ??
      PlaceSocial(
        placeId: widget.space.id,
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
      );

  @override
  void initState() {
    super.initState();
    _loadSocial();
    _loadComments();
  }

  Future<void> _loadSocial() async {
    try {
      final cached = await _community.readCachedPlaceSocial();
      if (mounted && cached != null) {
        setState(() => _allSocial = cached);
      }
    } catch (e) {
      debugPrint('Could not read cached location social data: $e');
    }

    try {
      final social = await _community.fetchPlaceSocial();
      if (!mounted) return;
      setState(() {
        _allSocial = social;
        _socialFailed = false;
      });
    } catch (e) {
      debugPrint('Location detail social error: $e');
      if (mounted) setState(() => _socialFailed = true);
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _community.fetchPlaceComments(widget.space.id);
      if (!mounted) return;
      setState(() {
        _comments = comments.reversed.take(3).toList();
        _commentsLoading = false;
        _commentsFailed = false;
      });
    } catch (e) {
      debugPrint('Location detail comments error: $e');
      if (!mounted) return;
      setState(() {
        _commentsLoading = false;
        _commentsFailed = true;
      });
    }
  }

  void _showConnectionMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This needs a connection. You are offline right now.'),
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (!ref.read(isOnlineProvider)) {
      _showConnectionMessage();
      return;
    }
    if (_liking) return;

    final previous = _social;
    final liked = !previous.likedByMe;
    setState(() {
      _liking = true;
      _allSocial[widget.space.id] = previous.copyWith(
        likedByMe: liked,
        likeCount: previous.likeCount + (liked ? 1 : -1),
      );
    });
    try {
      await _community.setPlaceLike(widget.space.id, liked);
      await _community.cachePlaceSocial(_allSocial);
    } catch (e) {
      debugPrint('Location detail like error: $e');
      if (mounted) {
        setState(() => _allSocial[widget.space.id] = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this like.')),
        );
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  void _openComments() {
    if (!ref.read(isOnlineProvider)) {
      _showConnectionMessage();
      return;
    }
    showPlaceCommentsSheet(
      context,
      placeId: widget.space.id,
      onCountChanged: (count) {
        if (!mounted) return;
        setState(() {
          _allSocial[widget.space.id] = _social.copyWith(commentCount: count);
        });
        _community.cachePlaceSocial(_allSocial).catchError((Object error) {
          debugPrint('Could not cache location comments count: $error');
        });
        _loadComments();
      },
    );
  }

  Future<void> _startCheckIn() async {
    if (_checkingLocation) return;
    setState(() => _checkingLocation = true);
    final position = await LocationService.currentPosition();
    if (!mounted) return;
    setState(() => _checkingLocation = false);

    if (position == null) {
      final retry = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Location unavailable'),
          content: const Text(
            'Turn on location and allow EcoWell to access it so we can check '
            'whether you have arrived.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
      if (retry == true && mounted) await _startCheckIn();
      return;
    }

    if (!mounted) return;
    if (isInsideGeofence(position, widget.space)) {
      await context.push<void>('/visit', extra: widget.space);
    } else {
      await context.push<void>(
        '/navigate?manualCheckIn=true',
        extra: widget.space,
      );
    }
  }

  Widget _heroFallback() => const DecoratedBox(
    decoration: BoxDecoration(gradient: AppColors.heroCardGradient),
    child: Center(
      child: Icon(Icons.park_outlined, size: 56, color: Colors.white),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final space = widget.space;
    final hasRating = space.quietRatingCount > 0 && space.quietScoreAvg != null;
    final address = space.address?.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.forestDark,
        title: const Text('Location Details'),
      ),
      body: OrganicBackgroundCircles(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _LocationHero(
              space: space,
              image: space.photoUrl == null
                  ? _heroFallback()
                  : CachedNetworkImage(
                      imageUrl: space.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _heroFallback(),
                      errorWidget: (_, _, _) => _heroFallback(),
                    ),
            ),
            const SizedBox(height: 16),
            _ScoreCard(
              score: hasRating ? space.quietScoreAvg! : null,
              ratingCount: space.quietRatingCount,
            ),
            const SizedBox(height: 16),
            _InfoCard(
              category: space.categoryLabel,
              address: address == null || address.isEmpty ? null : address,
              description: space.description,
              latitude: space.lat,
              longitude: space.lng,
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _checkingLocation ? null : _startCheckIn,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mintGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _checkingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.spa_outlined),
                label: Text(
                  _checkingLocation
                      ? 'Checking your location...'
                      : 'Check in and rate this sanctuary',
                ),
              ),
            ),
            const SizedBox(height: 24),
            _CommunitySection(
              comments: _comments,
              count: _social.commentCount,
              loading: _commentsLoading,
              failed: _commentsFailed,
              socialFailed: _socialFailed,
              onRetry: _loadComments,
              onLike: _toggleLike,
              onComments: _openComments,
              likedByMe: _social.likedByMe,
              likeCount: _social.likeCount,
              liking: _liking,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationHero extends StatelessWidget {
  const _LocationHero({required this.space, required this.image});

  final GreenSpace space;
  final Widget image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC143D2B)],
                  stops: [0.38, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.mintLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        space.categoryLabel.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    space.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (space.address?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      space.address!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score, required this.ratingCount});

  final double? score;
  final int ratingCount;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Row(
        children: [
          const Icon(Icons.spa_outlined, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Quiet & Tranquility Score',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score?.toStringAsFixed(1) ?? '—',
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
              Text(
                ratingCount == 0
                    ? 'Not rated yet'
                    : '$ratingCount ${ratingCount == 1 ? 'rating' : 'ratings'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.category,
    required this.address,
    required this.description,
    required this.latitude,
    required this.longitude,
  });

  final String category;
  final String? address;
  final String? description;
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Location Information'),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.category_outlined,
            label: 'Category',
            value: category,
          ),
          if (address != null)
            _InfoLine(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: address!,
            ),
          if (description?.trim().isNotEmpty ?? false)
            _InfoLine(
              icon: Icons.notes_outlined,
              label: 'About',
              value: description!.trim(),
            ),
          _InfoLine(
            icon: Icons.my_location_outlined,
            label: 'Coordinates',
            value:
                '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
          ),
        ],
      ),
    );
  }
}

class _CommunitySection extends StatelessWidget {
  const _CommunitySection({
    required this.comments,
    required this.count,
    required this.loading,
    required this.failed,
    required this.socialFailed,
    required this.onRetry,
    required this.onLike,
    required this.onComments,
    required this.likedByMe,
    required this.likeCount,
    required this.liking,
  });

  final List<PlaceComment> comments;
  final int count;
  final bool loading;
  final bool failed;
  final bool socialFailed;
  final VoidCallback onRetry;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final bool likedByMe;
  final int likeCount;
  final bool liking;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('Community Logs')),
            TextButton(onPressed: onComments, child: const Text('View all')),
          ],
        ),
        if (socialFailed)
          const Text(
            'Showing saved counts. Connect to refresh.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        _DetailCard(
          child: Row(
            children: [
              IconButton(
                tooltip: likedByMe ? 'Unlike place' : 'Like place',
                onPressed: liking ? null : onLike,
                icon: Icon(
                  likedByMe ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                ),
              ),
              Text('$likeCount likes'),
              const Spacer(),
              TextButton.icon(
                onPressed: onComments,
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text('$count comments'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          )
        else if (failed)
          _DetailCard(
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Community comments could not be loaded.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          )
        else if (comments.isEmpty)
          _DetailCard(
            child: Text(
              count == 0
                  ? 'No community logs yet. Be the first to share a comment.'
                  : 'There are $count comments. Connect to view them.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          for (final comment in comments)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CommentCard(comment: comment),
            ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment});

  final PlaceComment comment;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: comment.authorName,
                url: comment.authorAvatar,
                radius: 16,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  comment.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                timeAgo(comment.createdAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(comment.body, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestDark.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.forestDark,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.primaryGreen),
          const SizedBox(width: 9),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
