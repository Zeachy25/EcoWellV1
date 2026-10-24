import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../community/data/community_repository.dart';
import '../../community/domain/community_models.dart';
import '../../community/presentation/comments_sheet.dart';
import '../../community/presentation/create_post_screen.dart';
import '../../community/presentation/my_day_row.dart';
import '../../community/presentation/my_day_viewer.dart';
import '../../community/presentation/post_card.dart';
import '../../community/presentation/suggested_users_section.dart';
import '../../home/data/profile_providers.dart';

/// Explore: a community feed of posts from EcoWell users.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  static const _pageSize = 20;

  final _scroll = ScrollController();
  List<FeedPost> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _failed = false;
  bool _followingOnly = false;
  int _suggestedKey = 0;
  List<MyDayStory> _stories = [];
  List<FollowedUser> _following = [];

  CommunityRepository get _repo => ref.read(communityRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
    _loadStories();
    _loadFollowing();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final list = await _repo.fetchFeed(followingOnly: _followingOnly);
      if (!mounted) return;
      setState(() {
        _posts = list;
        _hasMore = list.length >= _pageSize;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Feed error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _posts.isEmpty || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final list = await _repo.fetchFeed(
        before: _posts.last.createdAt,
        followingOnly: _followingOnly,
      );
      if (!mounted) return;
      setState(() {
        _posts = [..._posts, ...list];
        _hasMore = list.length >= _pageSize;
      });
    } catch (e) {
      debugPrint('Feed (more) error: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _suggestedKey++);
    await Future.wait([_load(), _loadStories(), _loadFollowing()]);
  }

  void _setFilter(bool followingOnly) {
    if (_followingOnly == followingOnly) return;
    setState(() => _followingOnly = followingOnly);
    _load();
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

  /// Actions that write to the server wait for the connection.
  bool _requireOnline() {
    if (ref.read(isOnlineProvider)) return true;
    _message('This needs a connection. You are offline right now.');
    return false;
  }

  Future<void> _toggleLike(FeedPost post) async {
    if (!_requireOnline()) return;
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

  Future<void> _onMenu(FeedPost post, PostMenuAction action) async {
    if (action == PostMenuAction.delete) {
      final ok = await showDialog<bool>(
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
      );
      if (ok != true) return;
      try {
        await _repo.deletePost(post);
        if (!mounted) return;
        setState(() => _posts = _posts.where((p) => p.id != post.id).toList());
      } catch (e) {
        debugPrint('Delete post error: $e');
        _message('Could not delete the post.');
      }
    } else {
      final reason = await showModalBottomSheet<String>(
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
      );
      if (reason == null) return;
      try {
        await _repo.reportPost(post.id, reason);
        _message('Thanks for letting us know. We will review it.');
      } catch (e) {
        debugPrint('Report error: $e');
        _message('You already reported this post, or it could not be sent.');
      }
    }
  }

  Future<void> _loadStories() async {
    try {
      final list = await _repo.fetchMyDayStories();
      if (!mounted) return;
      setState(() => _stories = list);
    } catch (e) {
      debugPrint('My Day error: $e');
    }
  }

  Future<void> _loadFollowing() async {
    try {
      final list = await _repo.fetchFollowing();
      if (!mounted) return;
      setState(() => _following = list);
    } catch (e) {
      debugPrint('Following error: $e');
    }
  }

  /// Tap on someone you follow: their My Day if they have one active,
  /// otherwise their profile with the posts they shared.
  void _openFollowedUser(FollowedUser user) {
    for (final s in _stories) {
      if (s.userId == user.id) {
        _openStory(s);
        return;
      }
    }
    context.push('/u/${user.id}');
  }

  Future<void> _openStory(MyDayStory story) async {
    final index = _stories.indexOf(story);
    if (index < 0) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => MyDayViewer(stories: _stories, initialIndex: index),
      ),
    );
    _loadStories(); // refresh rings and view counts
  }

  /// "Share a moment from your visit" adds to My Day (not to the feed).
  Future<void> _createMyDay() async {
    if (!_requireOnline()) return;
    final created = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const CreatePostScreen(myDay: true),
      ),
    );
    if (created == true) {
      _message('Added to your My Day.');
      _loadStories();
    }
  }

  Future<void> _create() async {
    if (!_requireOnline()) return;
    final created = await context.push<bool>('/post/new');
    if (created == true) {
      _message('Your post is live.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final p = profile.hasValue ? profile.value : null;
    final myName = (p?['full_name'] as String?) ?? '';
    final myAvatar = p?['avatar_url'] as String?;
    final myId = _repo.currentUserId;
    final online = ref.watch(isOnlineProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Explore'),
        centerTitle: false,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'New post',
            onPressed: _create,
            icon: const Icon(Icons.add_a_photo),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            Responsive.horizontalPadding(context),
            Responsive.size(context, 4),
            Responsive.horizontalPadding(context),
            Responsive.size(context, 24),
          ),
          children: [
            // The feed below is the last saved copy while offline.
            if (!online) ...[
              const _OfflineFeedNote(),
              SizedBox(height: Responsive.size(context, 12)),
            ],

            // My Day stories (only shown here, never in the feed)
            MyDayRow(
              stories: _stories,
              following: _following,
              myId: myId,
              myName: myName,
              myAvatar: myAvatar,
              onAdd: _createMyDay,
              onOpen: _openStory,
              onOpenUser: _openFollowedUser,
            ),
            SizedBox(height: Responsive.size(context, 16)),

            // Suggested people
            SuggestedUsersSection(key: ValueKey(_suggestedKey)),
            SizedBox(height: Responsive.size(context, 16)),

            // All / Following
            Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: !_followingOnly,
                  onSelected: (_) => _setFilter(false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Following'),
                  selected: _followingOnly,
                  onSelected: (_) => _setFilter(true),
                ),
              ],
            ),
            SizedBox(height: Responsive.size(context, 12)),

            ..._buildFeed(myId),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeed(String myId) {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_failed) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Could not load the feed. Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      ];
    }
    if (_posts.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.photo_camera_back_outlined,
                  size: 56, color: AppColors.mintGreen),
              const SizedBox(height: 12),
              Text(
                _followingOnly
                    ? 'Posts from people you follow will appear here. '
                        'Follow someone from the suggestions above.'
                    : 'No posts yet. Be the first to share a moment!',
                textAlign: TextAlign.center,
              ),
              if (!_followingOnly)
                TextButton(
                    onPressed: _create, child: const Text('Share a moment')),
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
          isMine: post.author.id == myId,
          onLike: () => _toggleLike(post),
          onComments: () => _openComments(post),
          onShare: () => _share(post),
          onMenu: (a) => _onMenu(post, a),
          onAuthorTap: (userId) => context.push('/u/$userId'),
        ),
      if (_loadingMore)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
    ];
  }
}
/// Shown at the top of Explore while offline: what is listed is the last
/// feed that was saved on the phone.
class _OfflineFeedNote extends StatelessWidget {
  const _OfflineFeedNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.streakOrange.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: AppColors.streakOrange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are offline. Showing the last posts you saw.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
