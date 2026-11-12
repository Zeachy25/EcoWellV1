import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'comments_sheet.dart';
import 'post_card.dart';
import 'share_sheet.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  FeedPost? _post;
  bool _loading = true;
  bool _failed = false;

  CommunityRepository get _repo => ref.read(communityRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final post = await _repo.fetchPost(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Post detail error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null) return;
    final liked = !post.likedByMe;
    setState(() {
      _post = post.copyWith(
        likedByMe: liked,
        likeCount: post.likeCount + (liked ? 1 : -1),
      );
    });
    try {
      await _repo.setLike(post.id, liked);
    } catch (e) {
      debugPrint('Like error: $e');
      if (!mounted) return;
      setState(() {
        _post = _post?.copyWith(
          likedByMe: !liked,
          likeCount: (_post?.likeCount ?? 0) + (liked ? -1 : 1),
        );
      });
      _message('Could not update your like.');
    }
  }

  void _openComments() {
    final post = _post;
    if (post == null) return;
    showCommentsSheet(
      context,
      post: post,
      onCountChanged: (n) {
        if (!mounted) return;
        setState(() => _post = _post?.copyWith(commentCount: n));
      },
    );
  }

  Future<void> _share() async {
    final post = _post;
    if (post == null) return;
    await openShareForPost(
      context,
      post: post,
      repo: _repo,
      onShared: () => _message('Shared to your feed.'),
    );
  }

  Future<void> _onMenu(PostMenuAction action) async {
    final post = _post;
    if (post == null) return;

    if (action == PostMenuAction.delete) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete this post?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await _repo.deletePost(post);
        if (!mounted) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      } catch (e) {
        debugPrint('Delete post error: $e');
        _message('Could not delete the post.');
      }
      return;
    }

    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Why are you reporting this post?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed || _post == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This post is no longer available.'),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    final post = _post!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PostCard(
          post: post,
          isMine: post.author.id == _repo.currentUserId,
          onLike: () => _toggleLike(),
          onComments: _openComments,
          onShare: () => _share(),
          onMenu: (a) => _onMenu(a),
          onAuthorTap: (userId) => context.push('/u/$userId'),
        ),
      ],
    );
  }
}
