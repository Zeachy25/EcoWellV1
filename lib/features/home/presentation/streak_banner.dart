import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';

class StreakBanner extends StatelessWidget {
  final int streak;
  const StreakBanner({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final started = streak > 0;
    return Container(
      padding: EdgeInsets.all(Responsive.size(context, 12)),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.streakOrange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department,
              color: AppColors.streakOrange, size: 30),
          SizedBox(width: Responsive.size(context, 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  started ? 'Visit streak' : 'Start your streak',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 11),
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  started
                      ? '$streak ${streak == 1 ? 'day' : 'days'}'
                      : 'Start your streak by visiting nature',
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 13),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}