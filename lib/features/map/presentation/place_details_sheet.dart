import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import '../domain/green_space.dart';
import 'map_helpers.dart';

class PlaceDetailsSheet extends StatelessWidget {
  const PlaceDetailsSheet({
    super.key,
    required this.space,
    required this.onDirections,
    this.distanceMeters,
  });

  final GreenSpace space;
  final double? distanceMeters;

  /// Opens the in-app directions screen.
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final distance = distanceMeters;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              space.name,
              style:
                  textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (space.address != null && space.address!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                space.address!,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  avatar: Icon(categoryIcon(space.category), size: 18),
                  label: Text(space.categoryLabel),
                ),
                if (distance != null) Chip(label: Text(formatDistance(distance))),
                Chip(label: Text('Quiet Score: ${quietScoreText(space)}')),
              ],
            ),
            const SizedBox(height: 12),
            Text(space.description ?? 'No description yet.'),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onDirections();
              },
              icon: const Icon(Icons.directions),
              label: const Text('Get directions'),
            ),
            const SizedBox(height: 8),
            Text(
              'Your check-in starts automatically when you arrive.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
