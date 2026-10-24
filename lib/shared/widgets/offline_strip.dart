import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Thin strip shown under the app bar while the phone has no connection.
/// The app keeps working from its saved content; this only sets the
/// expectation that some things (posting, directions, syncing) wait.
class OfflineStrip extends StatelessWidget {
  const OfflineStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.orangeLight,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, size: 16, color: AppColors.streakOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You are offline. Showing saved content.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
