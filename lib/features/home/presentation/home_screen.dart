import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/ecowell_logo.dart';
import '../../community/data/community_repository.dart';
import '../../community/domain/community_models.dart';
import '../../community/presentation/place_comments_sheet.dart';
import '../../community/presentation/suggested_users_section.dart';
import '../../map/data/map_providers.dart';
import '../../visit/data/visit_providers.dart';
import '../../visit/domain/visit_models.dart';
import '../../announcements/presentation/announcement_bell.dart';
import '../data/profile_providers.dart';
import 'active_visit_card.dart';
import 'hero_banner.dart';
import 'home_search_bar.dart';
import 'streak_banner.dart';
import 'weather_card.dart';

/// Home tab: profile, streak, and a card for a visit in progress.
/// If the profile has no birthdate or no consent yet (Google sign-in, old
/// test accounts), it sends the user to the Complete Profile screen first.
/// Keep this check when the real Home content is built.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // --- function: unchanged ---
  Future<void> _resume(
    BuildContext context,
    WidgetRef ref,
    ActiveVisitInfo visit,
  ) async {
    final spaces = await ref.read(greenSpacesProvider.future);
    final match = spaces.where((s) => s.id == visit.placeId);
    if (match.isEmpty || !context.mounted) return;
    await context.push<void>('/visit', extra: match.first);
    ref.invalidate(activeVisitProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // --- function: unchanged ---
    ref.listen<AsyncValue<Map<String, dynamic>>>(profileProvider, (_, next) {
      next.whenData((p) {
        if (p['birthdate'] == null || p['consented_at'] == null) {
          context.go('/complete-profile', extra: p['birthdate'] == null);
        }
      });
    });

    final profile = ref.watch(profileProvider);
    final activeAsync = ref.watch(activeVisitProvider);
    final active = activeAsync.hasValue ? activeAsync.value : null;

    // The layout always shows. Data that is missing (loading or offline)
    // only hides or replaces the parts that need it.
    final p = profile.hasValue ? profile.value : null;
    final name = p == null ? '' : '${p['full_name']}';
    final userId = p?['id'] as String? ?? '';
    final streak = p?['streak_count'];
    final streakNum = streak is num ? streak.toInt() : 0;
    final profileFailed = profile.hasError && !profile.hasValue;

    // Banner size, used to decide how much green sits behind it.
    final pad = Responsive.horizontalPadding(context) + 2;
    final bannerH =
        (MediaQuery.sizeOf(context).width - pad * 2) * HeroBanner.aspect;

    void retry() {
      ref.invalidate(profileProvider);
      ref.invalidate(greenSpacesProvider);
      ref.invalidate(activeVisitProvider);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Green header with the banner overlapping its bottom edge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    _Header(
                      name: name,
                      onProfile: userId.isEmpty
                          ? null
                          : () => context.push('/u/$userId'),
                      bottomExtra: bannerH * 0.45, // green behind banner
                    ),
                    SizedBox(height: bannerH * 0.55), // light part
                  ],
                ),
                Positioned(
                  left: pad,
                  right: pad,
                  bottom: 0,
                  child: const HeroBanner(),
                ),
              ],
            ),
            SizedBox(height: Responsive.size(context, 16)),

            // Shown when the profile could not be loaded (offline)
            if (profileFailed) ...[
              Padding(
                padding: _pad(context),
                child: _OfflineBanner(onRetry: retry),
              ),
              SizedBox(height: Responsive.size(context, 16)),
            ],

            // Streak: placeholder while loading, real value once known
            if (p != null)
              Padding(
                padding: _pad(context),
                child: StreakBanner(streak: streakNum),
              )
            else if (!profileFailed)
              Padding(
                padding: _pad(context),
                child: _LoadingBar(height: Responsive.size(context, 62)),
              ),

            // Visit in progress (real data, same _resume)
            if (active != null) ...[
              SizedBox(height: Responsive.size(context, 16)),
              Padding(
                padding: _pad(context),
                child: ActiveVisitCard(
                  placeName: active.placeName,
                  onTap: () => _resume(context, ref, active),
                ),
              ),
            ],

            SizedBox(height: Responsive.size(context, 16)),
            Padding(padding: _pad(context), child: const WeatherCard()),

            SizedBox(height: Responsive.size(context, 22)),
            Padding(
              padding: _pad(context),
              child: const SuggestedUsersSection(title: 'Who to Follow'),
            ),

            SizedBox(height: Responsive.size(context, 22)),
            const _SectionTitle(title: 'Wellness Score by Location'),
            SizedBox(height: Responsive.size(context, 6)),
            Padding(
              padding: _pad(context),
              child: Text(
                'Recommended for you - explore nearby places to help you '
                'relax, stay active, and recharge.',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 12),
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            SizedBox(height: Responsive.size(context, 12)),

            // Places from the green spaces in Supabase (filtered by search)
            const _PlacesSection(),
            SizedBox(height: Responsive.size(context, 32)),
          ],
        ),
      ),
    );
  }

  static EdgeInsets _pad(BuildContext context) => EdgeInsets.symmetric(
    horizontal: Responsive.horizontalPadding(context) + 2,
  );
}

// ─────────────────────────── Header ───────────────────────────

class _Header extends StatelessWidget {
  final String name;
  final VoidCallback? onProfile;

  /// Extra green space under the search bar, where the banner overlaps.
  final double bottomExtra;

  const _Header({
    required this.name,
    required this.onProfile,
    this.bottomExtra = 0,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B4D36), Color(0xFF143D2B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Responsive.horizontalPadding(context) + 2,
            Responsive.size(context, 10),
            Responsive.horizontalPadding(context) + 2,
            Responsive.size(context, 14) + bottomExtra,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar: logo + name (left), bell + avatar (right)
              Row(
                children: [
                  EcoWellLeafIcon(
                    size: Responsive.size(context, 26),
                    color: AppColors.mintGreen,
                  ),
                  SizedBox(width: Responsive.size(context, 8)),
                  Expanded(
                    child: Text(
                      'EcoWell',
                      style: TextStyle(
                        fontSize: Responsive.fontSize(context, 22),
                        fontWeight: FontWeight.w700,
                        fontFamily: 'serif',
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  const AnnouncementBell(),

                  // Tapping the avatar opens the signed-in user's profile.
                  InkWell(
                    onTap: onProfile,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: Responsive.size(context, 38),
                      height: Responsive.size(context, 38),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.mintGreen,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: Responsive.fontSize(context, 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: Responsive.size(context, 10)),

              // Greeting (generic until the name is known)
              Text(
                name.isEmpty ? 'Welcome!' : 'Hello, $name!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.fontSize(context, 15),
                ),
              ),
              SizedBox(height: Responsive.size(context, 12)),

              // Search bar (own file: home_search_bar.dart) + filter button
              Row(
                children: [
                  const Expanded(child: HomeSearchBar()),
                  SizedBox(width: Responsive.size(context, 10)),
                  Container(
                    width: Responsive.size(context, 40),
                    height: Responsive.size(context, 40),
                    decoration: BoxDecoration(
                      color: AppColors.streakOrange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    // Design only, no function yet
                    child: const Icon(Icons.tune, color: Colors.white),
                  ),
                ],
              ),
              // The hero banner is not here. It sits in HomeScreen.
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────── Offline and loading helpers ─────────────────

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfflineBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Responsive.size(context, 12)),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.streakOrange.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: AppColors.streakOrange),
          SizedBox(width: Responsive.size(context, 10)),
          Expanded(
            child: Text(
              'No connection. Some content could not be loaded.',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 12),
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Soft placeholder block shown where data is still loading.
class _LoadingBar extends StatelessWidget {
  final double height;
  const _LoadingBar({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
    );
  }
}

// ───────────────── Sections ─────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: HomeScreen._pad(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 16),
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'See All',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 12),
              fontWeight: FontWeight.w700,
              color: AppColors.textGreenTitle,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────── Places (real green spaces + search) ─────────────────

class _PlacesSection extends ConsumerStatefulWidget {
  const _PlacesSection();

  @override
  ConsumerState<_PlacesSection> createState() => _PlacesSectionState();
}

class _PlacesSectionState extends ConsumerState<_PlacesSection> {
  final Map<String, PlaceSocial> _placeSocial = {};
  final Set<String> _likingPlaces = {};
  bool _socialLoadFailed = false;

  CommunityRepository get _community => ref.read(communityRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _loadPlaceSocial();
  }

  PlaceSocial _socialFor(String placeId) =>
      _placeSocial[placeId] ??
      PlaceSocial(
        placeId: placeId,
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
      );

  Future<void> _loadPlaceSocial() async {
    try {
      final social = await _community.fetchPlaceSocial();
      if (!mounted) return;
      setState(() {
        _placeSocial
          ..clear()
          ..addAll(social);
        _socialLoadFailed = false;
      });
    } catch (e) {
      debugPrint('Home place social error: $e');
      if (mounted) setState(() => _socialLoadFailed = true);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _requireOnline() {
    if (ref.read(isOnlineProvider)) return true;
    _showMessage('This needs a connection. You are offline right now.');
    return false;
  }

  Future<void> _toggleLike(String placeId) async {
    if (!_requireOnline() || _likingPlaces.contains(placeId)) return;

    final previous = _socialFor(placeId);
    final liked = !previous.likedByMe;
    setState(() {
      _likingPlaces.add(placeId);
      _placeSocial[placeId] = previous.copyWith(
        likedByMe: liked,
        likeCount: previous.likeCount + (liked ? 1 : -1),
      );
    });

    try {
      await _community.setPlaceLike(placeId, liked);
    } catch (e) {
      debugPrint('Home place like error: $e');
      if (mounted) {
        setState(() => _placeSocial[placeId] = previous);
        _showMessage(
          'Could not update this like. Check the Supabase place-social setup.',
        );
      }
    } finally {
      if (mounted) setState(() => _likingPlaces.remove(placeId));
    }
  }

  void _openComments(String placeId) {
    if (!_requireOnline()) return;
    showPlaceCommentsSheet(
      context,
      placeId: placeId,
      onCountChanged: (count) {
        if (!mounted) return;
        setState(() {
          _placeSocial[placeId] = _socialFor(
            placeId,
          ).copyWith(commentCount: count);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacesAsync = ref.watch(greenSpacesProvider);

    return spacesAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.all(Responsive.size(context, 24)),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      ),
      error: (e, _) => Padding(
        padding: HomeScreen._pad(context),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Could not load places.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(greenSpacesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (spaces) {
        return ValueListenableBuilder<String>(
          valueListenable: homeSearchQuery,
          builder: (context, query, _) {
            final q = query.trim().toLowerCase();
            final searching = q.isNotEmpty;

            final matches = searching
                ? spaces.where((s) => s.name.toLowerCase().contains(q)).toList()
                : spaces.take(5).toList(); // no search: first 5 places

            if (matches.isEmpty) {
              return Padding(
                padding: HomeScreen._pad(context),
                child: Text(
                  searching
                      ? 'No places match "$query".'
                      : 'No green spaces yet.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            final pad = HomeScreen._pad(context);
            return Column(
              children: [
                if (_socialLoadFailed)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      pad.left,
                      0,
                      pad.right,
                      Responsive.size(context, 10),
                    ),
                    child: const Text(
                      'Location likes and comments could not load. Check your connection and Supabase setup.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                for (final s in matches)
                  Padding(
                    padding: EdgeInsets.only(
                      left: pad.left,
                      right: pad.right,
                      bottom: Responsive.size(context, 14),
                    ),
                    child: _PlaceCard(
                      name: s.name,
                      // No address field in GreenSpace, so show the category.
                      address: s.categoryLabel,
                      // Quiet Score, only when at least one person rated it.
                      rating: s.quietRatingCount > 0
                          ? s.quietScoreAvg?.toStringAsFixed(1)
                          : null,
                      imageUrl: s.photoUrl,
                      social: _socialFor(s.id),
                      liking: _likingPlaces.contains(s.id),
                      onLike: () => _toggleLike(s.id),
                      onComments: () => _openComments(s.id),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final String name;
  final String? address;
  final String? rating;
  final String? imageUrl;
  final PlaceSocial social;
  final bool liking;
  final VoidCallback onLike;
  final VoidCallback onComments;
  const _PlaceCard({
    required this.name,
    required this.social,
    required this.liking,
    required this.onLike,
    required this.onComments,
    this.address,
    this.rating,
    this.imageUrl,
  });

  Widget _fallback() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF8CE0C7), Color(0xFF2E7D8B)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: const Center(
      child: Icon(Icons.park, color: Colors.white70, size: 48),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(Responsive.size(context, 12)),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.primaryGreen,
                  size: 18,
                ),
                SizedBox(width: Responsive.size(context, 6)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: Responsive.fontSize(context, 14),
                        ),
                      ),
                      if (address != null)
                        Text(
                          address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: Responsive.fontSize(context, 11),
                          ),
                        ),
                    ],
                  ),
                ),
                if (rating != null)
                  Column(
                    children: [
                      Text(
                        'Quiet Score',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: Responsive.fontSize(context, 10),
                        ),
                      ),
                      const Icon(
                        Icons.star,
                        color: AppColors.amberRating,
                        size: 18,
                      ),
                      Text(
                        rating!,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.fontSize(context, 11),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          SizedBox(
            height: Responsive.size(context, 170),
            width: double.infinity,
            child: imageUrl == null
                ? _fallback()
                : CachedNetworkImage(
                    // Cached, so the places list still has photos offline.
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _fallback(),
                    errorWidget: (context, url, error) => _fallback(),
                  ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.size(context, 12),
              vertical: Responsive.size(context, 8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: social.likedByMe ? 'Unlike place' : 'Like place',
                      onPressed: liking ? null : onLike,
                      icon: Icon(
                        social.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.red,
                      ),
                    ),
                    Text('${social.likeCount}'),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Comments',
                      onPressed: onComments,
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: AppColors.forestDark,
                      ),
                    ),
                    Text('${social.commentCount}'),
                  ],
                ),
                Icon(Icons.share_outlined, color: AppColors.forestDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
