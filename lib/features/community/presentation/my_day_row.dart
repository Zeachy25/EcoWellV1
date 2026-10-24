import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/community_models.dart';
import 'user_avatar.dart';

enum _Ring { none, unseen, seen }

/// Top of Explore: "Your day" tile beside a scrollable row of the people you
/// follow (hidden when you follow nobody). Orange ring = the person has a
/// My Day you have not watched yet; tapping opens their My Day or profile.
class MyDayRow extends StatelessWidget {
  const MyDayRow({
    super.key,
    required this.stories,
    required this.following,
    required this.myId,
    required this.myName,
    required this.onAdd,
    required this.onOpen,
    required this.onOpenUser,
    this.myAvatar,
  });

  final List<MyDayStory> stories;

  /// Everyone the user follows (shown beside "Your day").
  final List<FollowedUser> following;

  final String myId;
  final String myName;
  final String? myAvatar;
  final VoidCallback onAdd;
  final ValueChanged<MyDayStory> onOpen;
  final ValueChanged<FollowedUser> onOpenUser;

  @override
  Widget build(BuildContext context) {
    final mine = stories.where((s) => s.userId == myId).firstOrNull;
    final others = stories.where((s) => s.userId != myId).toList();
    final unseenIds = {
      for (final s in others)
        if (s.hasUnseen) s.userId,
    };

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
            if (following.isNotEmpty) ...[
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: following.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final u = following[i];
                      return _Tile(
                        label: u.name.split(' ').first,
                        name: u.name,
                        url: u.avatarUrl,
                        ring: unseenIds.contains(u.id)
                            ? _Ring.unseen
                            : _Ring.none,
                        onTap: () => onOpenUser(u),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
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