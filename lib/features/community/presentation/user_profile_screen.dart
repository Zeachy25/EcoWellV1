import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/data/auth_repository.dart';
import '../data/community_repository.dart';
import '../data/user_profile_repository.dart';
import '../domain/community_models.dart';
import '../domain/user_profile.dart';
import 'comments_sheet.dart';
import 'edit_profile_sheet.dart';
import 'home_widgets.dart';
import 'post_card.dart';
import 'user_avatar.dart';

/// A Facebook-style profile of any EcoWell user: cover photo, profile
/// picture, name, follower/following counts, "Joined" date, bio, photos
/// grid, then the posts they shared. Your own profile additionally offers
/// Edit profile and Log out.
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.userId,
    this.name = '',
    this.avatarUrl,
  });

  final String userId;

  /// Optional prefill, so the app bar has a title before the data arrives.
  final String name;
  final String? avatarUrl;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  List<FeedPost> _posts = [];
  bool _postsLoading = true;
  bool _postsFailed = false;

  /// Optimistic copy shown while a follow request is in flight; it is
  /// dropped as soon as the refreshed profile arrives from the server.
  UserProfile? _followOverride;

  CommunityRepository get _repo => ref.read(communityRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _postsLoading = true;
      _postsFailed = false;
    });
    try {
      final list = await _repo.fetchUserPosts(widget.userId);
      if (!mounted) return;
      setState(() {
        _posts = list;
        _postsLoading = false;
      });
    } catch (e) {
      debugPrint('User posts error: $e');
      if (!mounted) return;
      setState(() {
        _postsLoading = false;
        _postsFailed = true;
      });
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(userProfileProvider(widget.userId));
    await _loadPosts();
  }

  void _replace(FeedPost post) {
    if (!mounted) return;
    setState(() {
      _posts = [for (final p in _posts) p.id == post.id ? post : p];
    });
  }

  FeedPost? _find(String id) {
    for (final p in _posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openProfile(String userId) {
    if (userId == widget.userId) return;
    context.push('/u/$userId');
  }

  Future<void> _toggleLike(FeedPost post) async {
    final liked = !post.likedByMe;
    _replace(post.copyWith(
      likedByMe: liked,
      likeCount: post.likeCount + (liked ? 1 : -1),
    ));
    try {
      await _repo.setLike(post.id, liked);
    } catch (e) {
      debugPrint('Like error: $e');
      final current = _find(post.id);
      if (current != null) {
        _replace(current.copyWith(
          likedByMe: !liked,
          likeCount: current.likeCount + (liked ? -1 : 1),
        ));
      }
      _message('Could not update your like.');
    }
  }

  void _openComments(FeedPost post) {
    showCommentsSheet(
      context,
      post: post,
      onCountChanged: (n) {
        final current = _find(post.id);
        if (current != null) _replace(current.copyWith(commentCount: n));
      },
    );
  }

  Future<void> _share(FeedPost post) async {
    final text = '${post.author.name} shared ${post.placeName} on EcoWell'
        '${post.caption != null && post.caption!.isNotEmpty ? ': ${post.caption}' : ''}';
    await Clipboard.setData(ClipboardData(text: text));
    _message('Copied to your clipboard.');
  }

  void _onMenu(FeedPost post, PostMenuAction action) {
    if (action == PostMenuAction.delete) {
      // Only ever offered on your own posts.
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete this post?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete')),
          ],
        ),
      ).then((ok) async {
        if (ok != true) return;
        try {
          await _repo.deletePost(post);
          if (!mounted) return;
          setState(
              () => _posts = _posts.where((p) => p.id != post.id).toList());
        } catch (e) {
          debugPrint('Delete post error: $e');
          _message('Could not delete the post.');
        }
      });
    } else {
      showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Why are you reporting this post?',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final r in const [
                'Inappropriate content',
                'Spam',
                'Privacy concern',
                'Something else',
              ])
                ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r)),
            ],
          ),
        ),
      ).then((reason) async {
        if (reason == null) return;
        try {
          await _repo.reportPost(post.id, reason);
          _message('Thanks for letting us know. We will review it.');
        } catch (e) {
          debugPrint('Report error: $e');
          _message('You already reported this post, or it could not be sent.');
        }
      });
    }
  }

  Future<void> _toggleFollow(UserProfile p) async {
    final now = !p.followedByMe;
    setState(() => _followOverride = p.copyWith(
      followedByMe: now,
      followerCount: p.followerCount + (now ? 1 : -1),
    ));
    try {
      await _repo.setFollow(p.id, now);
      // The refreshed header becomes the source of truth again.
      ref.invalidate(userProfileProvider(p.id));
    } catch (e) {
      debugPrint('Follow error: $e');
      if (!mounted) return;
      setState(() => _followOverride = null);
      _message('Could not update. Please try again.');
    }
  }

  Future<void> _editProfile(UserProfile p) async {
    final saved = await showEditProfileSheet(context, profile: p);
    if (saved == true) {
      ref.invalidate(userProfileProvider(p.id));
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use EcoWell.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true) ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(userProfileProvider(widget.userId));
    final online = ref.watch(isOnlineProvider);

    // Drop the optimistic follow copy once a refreshed server answer
    // arrives (kept if the refresh fails, so the button keeps its state).
    ref.listen<AsyncValue<UserProfile?>>(
      userProfileProvider(widget.userId),
      (_, next) {
        if (_followOverride == null || next is! AsyncData<UserProfile?>) {
          return;
        }
        if (next.value == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _followOverride = null);
        });
      },
    );

    final profile = _followOverride ?? async.value;
    final myId = _repo.currentUserId;
    final isMe = widget.userId == myId;
    final title = profile?.name.isNotEmpty == true
        ? profile!.name
        : (widget.name.isEmpty ? 'Profile' : widget.name);

    if (profile == null && async.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar(title, isMe: false, profile: null),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (profile == null && async.hasError) {
      final client = Supabase.instance.client;
      final isMe = widget.userId == client.auth.currentUser?.id;
      if (isMe) {
        final user = client.auth.currentUser;
        final meta = user?.userMetadata ?? const {};
        final name = widget.name.isNotEmpty
            ? widget.name
            : (meta['full_name'] ??
                meta['name'] ??
                meta['display_name'] ??
                (user?.email?.split('@').first) ??
                'Profile');
        final avatar = widget.avatarUrl ?? (meta['avatar_url'] ?? meta['picture']);
        final pref = UserProfile(
          id: widget.userId,
          name: name ?? 'Profile',
          avatarUrl: avatar as String?,
          coverUrl: null,
          bio: null,
          joinedAt: user?.createdAt != null
              ? DateTime.tryParse(user!.createdAt)
              : null,
          followerCount: 0,
          followingCount: 0,
          postCount: 0,
          followedByMe: false,
        );
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _appBar(name ?? 'Profile', isMe: true, profile: pref),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    UserAvatar(name: pref.name, url: pref.avatarUrl, radius: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pref.name,
                            style: TextStyle(
                              fontSize: Responsive.fontSize(context, 18),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Offline · showing basic profile info',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _editProfile(pref),
                      child: const Text('Edit profile'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.size(context, 16),
                ),
                child: Text(
                  'Posts',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontSize(context, 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ..._buildPosts(pref, true),
            ],
          ),
        );
      }
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar(title, isMe: false, profile: null),
        body: _ProfileMessage(
          icon: Icons.cloud_off,
          text: 'Could not load this profile. Check your connection '
              'and try again.',
          buttonLabel: 'Try again',
          onPressed: () => ref.invalidate(userProfileProvider(widget.userId)),
        ),
      );
    }
    if (profile == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _appBar('Profile', isMe: false, profile: null),
        body: const _ProfileMessage(
          icon: Icons.person_search_outlined,
          text: 'This profile could not be found.',
        ),
      );
    }

    final photos = <String>[
      for (final post in _posts) ...post.photoPaths,
    ].take(9).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(profile.name, isMe: isMe, profile: profile),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // A cached profile stays readable offline, with a clear label.
            if (!online) ...[
              const _OfflineProfileNote(),
              SizedBox(height: Responsive.size(context, 12)),
            ],
            _buildCoverAndAvatar(profile, isMe),
            Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.horizontalPadding(context),
                Responsive.size(context, 56),
                Responsive.horizontalPadding(context),
                Responsive.size(context, 24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(profile, isMe),
                  SizedBox(height: Responsive.size(context, 16)),
                  if (photos.isNotEmpty) ...[
                    SectionTitle(title: 'Photos'),
                    SizedBox(height: Responsive.size(context, 12)),
                    _buildPhotos(photos),
                    SizedBox(height: Responsive.size(context, 20)),
                  ],
                  SectionTitle(title: 'Posts'),
                  SizedBox(height: Responsive.size(context, 12)),
                  ..._buildPosts(profile, isMe),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────

  PreferredSizeWidget _appBar(String title,
      {required bool isMe, required UserProfile? profile}) {
    return AppBar(
      title: Text(title),
      centerTitle: false,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      actions: [
        if (isMe && profile != null)
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (value) {
              if (value == 'edit') _editProfile(profile);
              if (value == 'logout') _confirmLogout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Edit profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 10),
                    Text('Log out'),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ── Cover + profile picture ────────────────────────────────────────────

  Widget _buildCoverAndAvatar(UserProfile profile, bool isMe) {
    final coverH = Responsive.size(context, 190);
    final url = profile.coverUrl;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover photo (or a green placeholder until one is chosen).
        Container(
          width: double.infinity,
          height: coverH,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B4D36), Color(0xFF38B289)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: url == null || url.isEmpty
              ? null
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
        ),
        // Camera button to change the cover (own profile only).
        if (isMe)
          Positioned(
            right: Responsive.size(context, 16),
            bottom: Responsive.size(context, 14),
            child: _RoundCameraButton(
              size: Responsive.size(context, 38),
              onTap: () => _editProfile(profile),
            ),
          ),
        // Profile picture, overlapping the bottom edge of the cover.
        Positioned(
          left: Responsive.size(context, 20),
          bottom: -Responsive.size(context, 44),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: UserAvatar(
              name: profile.name,
              url: profile.avatarUrl,
              radius: Responsive.size(context, 50),
            ),
          ),
        ),
      ],
    );
  }

  // ── Name, counts, joined, bio, buttons ─────────────────────────────────

  Widget _buildHeader(UserProfile profile, bool isMe) {
    final followers = formatCount(profile.followerCount);
    final following = formatCount(profile.followingCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.name,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: Responsive.fontSize(context, 24),
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: Responsive.size(context, 6)),
        Text(
          '$followers ${profile.followerCount == 1 ? 'follower' : 'followers'}'
          ' · $following ${profile.followingCount == 1 ? 'following' : 'following'}',
          style: TextStyle(
            fontSize: Responsive.fontSize(context, 14),
            color: AppColors.textSecondary,
          ),
        ),
        if (profile.joinedAt != null) ...[
          SizedBox(height: Responsive.size(context, 6)),
          Row(
            children: [
              const Icon(Icons.event_available_outlined,
                  size: 15, color: AppColors.textTertiary),
              const SizedBox(width: 5),
              Text(
                'Joined ${formatMonthYear(profile.joinedAt!)}',
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 13),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: Responsive.size(context, 10)),
        if (profile.bio != null)
          Text(
            profile.bio!,
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 14),
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          )
        else if (isMe)
          GestureDetector(
            onTap: () => _editProfile(profile),
            child: Text(
              'Add a bio...',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                fontWeight: FontWeight.w700,
                color: AppColors.mintGreen,
              ),
            ),
          ),
        SizedBox(height: Responsive.size(context, 14)),
        if (isMe)
          SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton.icon(
              onPressed: () => _editProfile(profile),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit profile'),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 40,
            child: profile.followedByMe
                ? OutlinedButton.icon(
                    onPressed: () => _toggleFollow(profile),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.streakOrange,
                      side: const BorderSide(color: AppColors.streakOrange),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Following'),
                  )
                : FilledButton.icon(
                    onPressed: () => _toggleFollow(profile),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.streakOrange,
                    ),
                    icon: const Icon(Icons.person_add_alt_1_outlined,
                        size: 18),
                    label: const Text('Follow'),
                  ),
          ),
      ],
    );
  }

  // ── Photos grid ────────────────────────────────────────────────────────

  Widget _buildPhotos(List<String> photos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: Responsive.size(context, 6),
        mainAxisSpacing: Responsive.size(context, 6),
      ),
      itemCount: photos.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => _openPhoto(photos, i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Responsive.radius(context, 10)),
          child: CachedNetworkImage(
            imageUrl: CommunityRepository.photoUrl(photos[i]),
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => Container(
              color: AppColors.cardBorder,
              child: const Icon(Icons.image_outlined,
                  color: AppColors.textTertiary),
            ),
          ),
        ),
      ),
    );
  }

  void _openPhoto(List<String> photos, int index) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: PageView.builder(
            itemCount: photos.length,
            controller: PageController(initialPage: index),
            itemBuilder: (context, i) => InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: CommunityRepository.photoUrl(photos[i]),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Posts ──────────────────────────────────────────────────────────────

  List<Widget> _buildPosts(UserProfile profile, bool isMe) {
    if (_postsLoading) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_postsFailed) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Could not load posts. Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              TextButton(onPressed: _loadPosts, child: const Text('Try again')),
            ],
          ),
        ),
      ];
    }
    if (_posts.isEmpty) {
      final firstName = profile.name.isEmpty
          ? 'This person'
          : profile.name.split(' ').first;
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.photo_camera_back_outlined,
                  size: 56, color: AppColors.mintGreen),
              const SizedBox(height: 12),
              Text(
                isMe
                    ? 'You have not shared a moment yet.'
                    : '$firstName has not shared any moments yet.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }
    return [
      for (final post in _posts)
        PostCard(
          key: ValueKey(post.id),
          post: post,
          isMine: post.author.id == _repo.currentUserId,
          onLike: () => _toggleLike(post),
          onComments: () => _openComments(post),
          onShare: () => _share(post),
          onMenu: (a) => _onMenu(post, a),
          onAuthorTap: _openProfile,
        ),
    ];
  }
}

/// Full-screen state used when the profile id is unknown.
class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({
    required this.icon,
    required this.text,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String text;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.mintGreen),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            if (buttonLabel != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onPressed, child: Text(buttonLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundCameraButton extends StatelessWidget {
  const _RoundCameraButton({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.camera_alt_outlined,
              size: 20, color: AppColors.forestMid),
        ),
      ),
    );
  }
}

/// Shown on a profile while offline: what is listed is the last copy that
/// was saved on the phone.
class _OfflineProfileNote extends StatelessWidget {
  const _OfflineProfileNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.streakOrange.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: AppColors.streakOrange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are offline. Showing the last saved info.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
