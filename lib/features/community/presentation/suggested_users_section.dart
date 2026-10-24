import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import 'home_widgets.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'user_avatar.dart';

/// "Suggested" / "Who to Follow": people you may want to follow, with
/// Follow and Remove buttons. Used on Home and on Explore.
class SuggestedUsersSection extends ConsumerStatefulWidget {
  const SuggestedUsersSection({
    super.key,
    this.title = 'Suggested',
    this.onSeeAll,
  });

  final String title;
  final VoidCallback? onSeeAll;

  @override
  ConsumerState<SuggestedUsersSection> createState() =>
      _SuggestedUsersSectionState();
}

class _SuggestedUsersSectionState extends ConsumerState<SuggestedUsersSection> {
  List<SuggestedUser>? _users;
  bool _loading = true;
  bool _failed = false;

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
      final list = await ref.read(communityRepositoryProvider).fetchSuggested();
      if (!mounted) return;
      setState(() {
        _users = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _toggleFollow(SuggestedUser u) async {
    final now = !u.following;
    _replace(u.copyWith(following: now, followers: u.followers + (now ? 1 : -1)));
    try {
      await ref.read(communityRepositoryProvider).setFollow(u.id, now);
    } catch (_) {
      _replace(u); // put it back
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update. Please try again.')),
      );
    }
  }

  void _replace(SuggestedUser u) {
    final list = _users;
    if (list == null || !mounted) return;
    setState(() {
      _users = [for (final x in list) x.id == u.id ? u : x];
    });
  }

  void _remove(SuggestedUser u) {
    setState(() => _users = _users?.where((x) => x.id != u.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;

    Widget body;
    if (_loading) {
      body = const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_failed) {
      body = Row(
        children: [
          const Expanded(child: Text('Could not load suggestions.')),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ],
      );
    } else if (users == null || users.isEmpty) {
      body = Text(
        'No suggestions yet. Invite friends to join EcoWell!',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: Responsive.fontSize(context, 13),
        ),
      );
    } else {
      body = SizedBox(
        height: Responsive.size(context, 212),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: users.length,
          separatorBuilder: (_, _) => SizedBox(width: Responsive.size(context, 12)),
          itemBuilder: (context, i) => IntrinsicHeight(
            child: _SuggestedCard(
              user: users[i],
              onFollow: () => _toggleFollow(users[i]),
              onRemove: () => _remove(users[i]),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: widget.title,
          actionLabel: widget.onSeeAll == null ? null : 'See All',
          onAction: widget.onSeeAll,
        ),
        SizedBox(height: Responsive.size(context, 12)),
        body,
      ],
    );
  }
}

class _SuggestedCard extends StatelessWidget {
  const _SuggestedCard({
    required this.user,
    required this.onFollow,
    required this.onRemove,
  });

  final SuggestedUser user;
  final VoidCallback onFollow;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Responsive.radius(context, 16)),
      onTap: () => context.push('/u/${user.id}'),
      child: Container(
        width: Responsive.size(context, 148),
        height: double.infinity,
        padding: EdgeInsets.all(Responsive.size(context, 12)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Responsive.radius(context, 16)),
          border: Border.all(color: AppColors.cardBorder),
        ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          UserAvatar(
            name: user.name,
            url: user.avatarUrl,
            radius: Responsive.size(context, 26),
            ring: true,
          ),
          const Spacer(),
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: Responsive.fontSize(context, 13),
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '${formatCount(user.followers)} '
            '${user.followers == 1 ? 'Follower' : 'Followers'}',
            style: TextStyle(
              fontSize: Responsive.fontSize(context, 11),
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: user.following
                ? OutlinedButton(
                    onPressed: onFollow,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppColors.streakOrange,
                      side: const BorderSide(color: AppColors.streakOrange),
                    ),
                    child: const Text('Following', style: TextStyle(fontSize: 12)),
                  )
                : FilledButton(
                    onPressed: onFollow,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      backgroundColor: AppColors.streakOrange,
                    ),
                    child: const Text('Follow', style: TextStyle(fontSize: 12)),
                  ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: OutlinedButton(
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.cardBorder),
              ),
              child: const Text('Remove', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
