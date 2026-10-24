import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'user_avatar.dart';

/// Opens the comments of a green space. [onCountChanged] gets the new total.
Future<void> showPlaceCommentsSheet(
  BuildContext context, {
  required String placeId,
  required ValueChanged<int> onCountChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) =>
        _PlaceCommentsSheet(placeId: placeId, onCountChanged: onCountChanged),
  );
}

class _PlaceCommentsSheet extends ConsumerStatefulWidget {
  const _PlaceCommentsSheet({
    required this.placeId,
    required this.onCountChanged,
  });

  final String placeId;
  final ValueChanged<int> onCountChanged;

  @override
  ConsumerState<_PlaceCommentsSheet> createState() =>
      _PlaceCommentsSheetState();
}

class _PlaceCommentsSheetState extends ConsumerState<_PlaceCommentsSheet> {
  final _input = TextEditingController();
  List<PlaceComment> _comments = [];
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;

  CommunityRepository get _repo => ref.read(communityRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final list = await _repo.fetchPlaceComments(widget.placeId);
      if (!mounted) return;
      setState(() {
        _comments = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Place comments error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.addPlaceComment(widget.placeId, text);
      _input.clear();
      await _load();
      widget.onCountChanged(_comments.length);
    } catch (e) {
      debugPrint('Add place comment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post your comment.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(PlaceComment c) async {
    try {
      await _repo.deletePlaceComment(c.id);
      setState(() => _comments = _comments.where((x) => x.id != c.id).toList());
      widget.onCountChanged(_comments.length);
    } catch (e) {
      debugPrint('Delete place comment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the comment.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final height = MediaQuery.sizeOf(context).height * 0.7;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Text('Comments',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(child: _buildList()),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send, color: AppColors.streakOrange),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tap on a commenter: close this sheet, then open their profile.
  void _openProfile(String userId) {
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    navigator.pop();
    router.push('/u/$userId');
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load comments.'),
            TextButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return const Center(child: Text('No comments yet. Say something kind!'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _comments.length,
      itemBuilder: (context, i) {
        final c = _comments[i];
        final canDelete = c.userId == _repo.currentUserId;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _openProfile(c.userId),
                child: UserAvatar(
                    name: c.authorName, url: c.authorAvatar, radius: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () => _openProfile(c.userId),
                            child: Text(
                              c.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo(c.createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(c.body),
                  ],
                ),
              ),
              if (canDelete)
                IconButton(
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _delete(c),
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.textSecondary),
                ),
            ],
          ),
        );
      },
    );
  }
}
