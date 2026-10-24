import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../data/weather_providers.dart';
import '../domain/weather_models.dart';

class WeatherCard extends ConsumerWidget {
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
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: Responsive.fontSize(context, 11),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(weatherProvider);
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/weather'),
          child: Padding(
            padding: EdgeInsets.all(Responsive.size(context, 1)),
            child: weather.when(
              loading: () => _buildStatus(
                context,
                icon: Icons.cloud_outlined,
                message: 'Loading local weather…',
                showProgress: true,
              ),
              error: (error, stackTrace) => _buildStatus(
                context,
                icon: Icons.cloud_off_outlined,
                message: 'Weather is currently unavailable.',
                action: TextButton(
                  onPressed: () => ref.invalidate(weatherProvider),
                  child: const Text(
                    'Try again',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              data: (data) => _buildWeather(context, data),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(
    BuildContext context, {
    required IconData icon,
    required String message,
    bool showProgress = false,
    Widget? action,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: Responsive.fontSize(context, 13),
                ),
              ),
            ),
            if (showProgress)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
          ],
        ),
        ?action,
        const SizedBox(height: 8),
        const _WeatherAttribution(),
      ],
    );
  }

  Widget _buildWeather(BuildContext context, WeatherData data) {
    final uv = data.uvIndex == data.uvIndex.roundToDouble()
        ? data.uvIndex.toStringAsFixed(0)
        : data.uvIndex.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.placeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textOnDarkMuted,
            fontSize: Responsive.fontSize(context, 12),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.tempC.round()}°C',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.fontSize(context, 38),
                  ),
                ),
                Text(
                  data.description,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Responsive.fontSize(context, 13),
                  ),
                ),
              ],
            ),
            Icon(data.icon, color: Colors.white70, size: 56),
          ],
        ),
        SizedBox(height: Responsive.size(context, 10)),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _chip(
              context,
              Icons.water_drop_outlined,
              '${data.humidity}% Humidity',
            ),
            _chip(context, Icons.air, '${data.windKmh.round()} km/h'),
            _chip(context, Icons.wb_sunny_outlined, 'UV $uv'),
          ],
        ),
        SizedBox(height: Responsive.size(context, 8)),
        const _WeatherAttribution(),
      ],
    );
  }
}

class _WeatherAttribution extends StatelessWidget {
  const _WeatherAttribution();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Weather by Open-Meteo',
      style: TextStyle(
        color: AppColors.textOnDarkMuted.withValues(alpha: 0.8),
        fontSize: Responsive.fontSize(context, 10),
      ),
    );
  }
}
