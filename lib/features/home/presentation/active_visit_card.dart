import 'package:flutter/material.dart';

import '../../../../core/utils/responsive.dart';

class ActiveVisitCard extends StatelessWidget {
  final String placeName;
  final VoidCallback onTap;
  const ActiveVisitCard({
    super.key,
    required this.placeName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF75C19F), Color(0xFF1E5241)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E5241).withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(Responsive.size(context, 14)),
            child: Row(
              children: [
                const Icon(Icons.park, color: Colors.white),
                SizedBox(width: Responsive.size(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visit in progress at $placeName',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.fontSize(context, 14),
                        ),
                      ),
                      Text(
                        'Tap to continue your check-in',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: Responsive.fontSize(context, 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}