import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';

/// Design placeholder: all values are sample text, not real weather data.
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  Widget _chip(BuildContext context, IconData icon, String text) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.size(context, 10),
          vertical: Responsive.size(context, 6),
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(text,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.fontSize(context, 11))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.size(context, 16)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4D36), Color(0xFF143D2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sample City, Philippines',
              style: TextStyle(
                  color: AppColors.textOnDarkMuted,
                  fontSize: Responsive.fontSize(context, 12))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('28°C',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: Responsive.fontSize(context, 38))),
                  Text('Partly Cloudy',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: Responsive.fontSize(context, 13))),
                ],
              ),
              const Icon(Icons.cloud_outlined, color: Colors.white54, size: 56),
            ],
          ),
          SizedBox(height: Responsive.size(context, 10)),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(context, Icons.water_drop_outlined, '72% Humidity'),
              _chip(context, Icons.air, '12 km/h'),
              _chip(context, Icons.wb_sunny_outlined, 'UV 6'),
            ],
          ),
        ],
      ),
    );
  }
}