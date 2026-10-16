import 'package:flutter/material.dart';

import '../../../shared/widgets/placeholder_screen.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Explore',
      icon: Icons.explore,
      message: 'Tips and ideas for spending time in nature will appear here.',
    );
  }
}
