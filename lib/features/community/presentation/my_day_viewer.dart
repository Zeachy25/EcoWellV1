import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'user_avatar.dart';

/// Full-screen My Day viewer.
///
/// Tap right/left for next/previous photo, hold to pause, swipe sideways to
/// switch person, swipe down (or X) to close. Your own My Days show a view
/// count and a delete button.
class MyDayViewer extends ConsumerStatefulWidget {
  const MyDayViewer({super.key, required this.stories, this.initialIndex = 0});

  final List<MyDayStory> stories;
  final int initialIndex;

  @override
  ConsumerState<MyDayViewer> createState() => _MyDayViewerState();
}

class _MyDayViewerState extends ConsumerState<MyDayViewer> {
  late final PageController _pager =
      PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  CommunityRepository get _repo => ref.read(communityRepositoryProvider);

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
  }

  void _nextStory() {
    if (_current < widget.stories.length - 1) {
      _pager.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _close();
    }
  }

  /// Returns false when there is no previous person.
  bool _prevStory() {
    if (_current == 0) return false;
    _pager.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    return true;
  }

  Future<void> _seen(MyDayItem item) async {
    if (item.viewedByMe || item.userId == _repo.currentUserId) return;
    try {
      await _repo.markMyDayViewed(item.id);
    } catch (e) {
      debugPrint('Mark viewed error: $e');
    }
  }

  Future<void> _delete(MyDayItem item) async {
    try {
      await _repo.deleteMyDay(item);
      _close();
    } catch (e) {
      debugPrint('Delete My Day error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this My Day.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pager,
        itemCount: widget.stories.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          final story = widget.stories[i];
          return _StoryPage(
            key: ValueKey(story.userId),
            story: story,
            active: i == _current,
            isMine: story.userId == _repo.currentUserId,
            onSeen: _seen,
            onDelete: _delete,
            onNextStory: _nextStory,
            onPrevStory: _prevStory,
            onClose: _close,
          );
        },
      ),
    );
  }
}

class _StoryPage extends StatefulWidget {
  const _StoryPage({
    super.key,
    required this.story,
    required this.active,
    required this.isMine,
    required this.onSeen,
    required this.onDelete,
    required this.onNextStory,
    required this.onPrevStory,
    required this.onClose,
  });

  final MyDayStory story;
  final bool active;
  final bool isMine;
  final ValueChanged<MyDayItem> onSeen;
  final Future<void> Function(MyDayItem) onDelete;
  final VoidCallback onNextStory;
  final bool Function() onPrevStory;
  final VoidCallback onClose;

  @override
  State<_StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<_StoryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });

  int _i = 0;
  bool _ready = false; // current photo is on screen
  bool _holding = false;

  MyDayItem get _item => widget.story.items[_i];

  @override
  void initState() {
    super.initState();
    // Start at the first photo you have not watched yet.
    final firstUnseen = widget.story.items.indexWhere((e) => !e.viewedByMe);
    _i = (widget.isMine || firstUnseen < 0) ? 0 : firstUnseen;
  }

  @override
  void didUpdateWidget(covariant _StoryPage old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      if (widget.active) {
        if (_ready) _start();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _start() {
    _ctrl.forward(from: 0);
    widget.onSeen(_item);
  }

  void _onReady() {
    if (!mounted || _ready) return;
    _ready = true;
    if (widget.active && !_holding) _start();
  }

  void _goTo(int index) {
    setState(() {
      _i = index;
      _ready = false;
      _ctrl.value = 0;
    });
  }

  void _next() {
    if (_i < widget.story.items.length - 1) {
      _goTo(_i + 1);
    } else {
      widget.onNextStory();
    }
  }

  void _prev() {
    if (_i > 0) {
      _goTo(_i - 1);
    } else if (!widget.onPrevStory()) {
      _ctrl.forward(from: 0); // first photo of the first person: restart
    }
  }

  Future<void> _confirmDelete() async {
    _ctrl.stop();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this My Day?'),
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
    if (ok == true) {
      await widget.onDelete(_item);
    }
    if (mounted && ok != true && _ready) _ctrl.forward();
  }

  String? _visitText(MyDayItem item) {
    final parts = <String>[];
    if (item.visitMinutes != null) {
      parts.add(formatDuration(item.visitMinutes! * 60.0));
    }
    final r = item.stressReduction;
    if (r != null) {
      parts.add(r > 0
          ? 'Stress score down $r'
          : (r < 0 ? 'Stress score up ${-r}' : 'Stress score unchanged'));
    }
    return parts.isEmpty ? null : parts.join(' \u00b7 ');
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final story = widget.story;
    final visit = _visitText(item);
    final hasCaption = item.caption != null && item.caption!.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final w = MediaQuery.sizeOf(context).width;
        d.localPosition.dx < w / 3 ? _prev() : _next();
      },
      onLongPressStart: (_) {
        _holding = true;
        _ctrl.stop();
      },
      onLongPressEnd: (_) {
        _holding = false;
        if (_ready && widget.active) _ctrl.forward();
      },
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 300) widget.onClose();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          Image.network(
            CommunityRepository.photoUrl(item.photoPath),
            key: ValueKey(item.id),
            fit: BoxFit.cover,
            frameBuilder: (_, child, frame, __) {
              if (frame != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _onReady());
              }
              return child;
            },
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (_, __, ___) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _onReady());
              return const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 56),
              );
            },
          ),

          // Top shade
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 140,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Progress bars + header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Row(
                      children: [
                        for (var n = 0; n < story.items.length; n++)
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: AnimatedBuilder(
                                  animation: _ctrl,
                                  builder: (_, __) => LinearProgressIndicator(
                                    minHeight: 3,
                                    value: n < _i
                                        ? 1
                                        : (n == _i ? _ctrl.value : 0),
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation(
                                        Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                    child: Row(
                      children: [
                        UserAvatar(
                            name: story.name, url: story.avatarUrl, radius: 17),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.isMine ? 'Your day' : story.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeAgo(item.createdAt),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (widget.isMine)
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: _confirmDelete,
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white),
                          ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom: place, visit stats, caption, views
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _GlassChip(
                                icon: Icons.location_on, text: item.placeName),
                            if (visit != null)
                              _GlassChip(
                                  icon: Icons.self_improvement, text: visit),
                          ],
                        ),
                        if (hasCaption)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              item.caption!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.35,
                              ),
                            ),
                          ),
                        if (widget.isMine)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.visibility_outlined,
                                    size: 16, color: Colors.white70),
                                const SizedBox(width: 6),
                                Text(
                                  '${formatCount(item.viewCount)} '
                                  '${item.viewCount == 1 ? 'view' : 'views'}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}