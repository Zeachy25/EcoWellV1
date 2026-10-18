import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/community_models.dart';
import 'user_avatar.dart';

enum _Ring { none, unseen, seen }

/// Top of Explore: "Your day" tile with the "Share a moment from your visit"
/// box beside it. Below that, a row with the My Days of people you follow
/// (only shown when there are some). Orange ring = not watched yet,
/// grey = watched.
class MyDayRow extends StatelessWidget {
  const MyDayRow({
    super.key,
    required this.stories,
    required this.myId,
    required this.myName,
    required this.onAdd,
    required this.onOpen,
    this.myAvatar,
  });

  final List<MyDayStory> stories;
  final String myId;
  final String myName;
  final String? myAvatar;
  final VoidCallback onAdd;
  final ValueChanged<MyDayStory> onOpen;

  @override
  Widget build(BuildContext context) {
    final mine = stories.where((s) => s.userId == myId).firstOrNull;
    final others = stories.where((s) => s.userId != myId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Tile(
              label: 'Your day',
              name: myName,
              url: myAvatar,
              ring: mine == null ? _Ring.none : _Ring.unseen,
              showPlus: true,
              onTap: mine == null ? onAdd : () => onOpen(mine),
              onPlus: onAdd,
            ),
            const SizedBox(width: 12),
            Expanded(child: _ShareBox(onTap: onAdd)),
          ],
        ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: others.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final s = others[i];
                return _Tile(
                  label: s.name.split(' ').first,
                  name: s.name,
                  url: s.avatarUrl,
                  ring: s.hasUnseen ? _Ring.unseen : _Ring.seen,
                  onTap: () => onOpen(s),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// "Share a moment from your visit..." with the camera-plus icon on the left.
/// Same height as the avatar next to it (2 * (28 + 3) = 62).
class _ShareBox extends StatelessWidget {
  const _ShareBox({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 62,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.streakOrange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_a_photo, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Share a moment from your visit...',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.name,
    required this.ring,
    required this.onTap,
    this.url,
    this.showPlus = false,
    this.onPlus,
  });

  final String label;
  final String name;
  final String? url;
  final _Ring ring;
  final bool showPlus;
  final VoidCallback onTap;
  final VoidCallback? onPlus;

  static const _radius = 28.0;

  Widget _avatar() {
    switch (ring) {
      case _Ring.unseen:
        return UserAvatar(name: name, url: url, radius: _radius, ring: true);
      case _Ring.seen:
        // Same outer size as the orange ring (radius + 3).
        return Container(
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.cardBorder, width: 2),
          ),
          child: UserAvatar(name: name, url: url, radius: _radius),
        );
      case _Ring.none:
        return Padding(
          padding: const EdgeInsets.all(3),
          child: UserAvatar(name: name, url: url, radius: _radius),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _avatar(),
                if (showPlus)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: onPlus,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.streakOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.add,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    ring == _Ring.unseen ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}