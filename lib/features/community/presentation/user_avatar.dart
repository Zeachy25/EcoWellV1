import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Round avatar: the photo if there is one, otherwise the first letter.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.url,
    this.radius = 20,
    this.ring = false,
  });

  final String name;
  final String? url;
  final double radius;

  /// Orange ring around the avatar (like in the design).
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    final hasUrl = url != null && url!.isNotEmpty;

    final inner = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.mintGreen,
      // Cached, so avatars of the saved feed still show while offline.
      foregroundImage: hasUrl ? CachedNetworkImageProvider(url!) : null,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );

    if (!ring) return inner;
    return CircleAvatar(
      radius: radius + 3,
      backgroundColor: AppColors.streakOrange,
      child: CircleAvatar(
        radius: radius + 1,
        backgroundColor: Colors.white,
        child: inner,
      ),
    );
  }
}
