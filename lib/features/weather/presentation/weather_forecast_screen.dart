import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/region.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/background_pattern.dart';
import '../../map/data/map_providers.dart';
import '../../map/domain/green_space.dart';
import '../data/weather_providers.dart';
import '../domain/weather_models.dart';

const _background = AppColors.background;
const _surface = AppColors.surface;
const _surfaceLight = AppColors.surfaceMuted;
const _muted = AppColors.textSecondary;
const _accent = AppColors.primaryGreen;

class WeatherForecastScreen extends ConsumerWidget {
  const WeatherForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(weatherForecastProvider);
    final spaces = ref.watch(greenSpacesProvider);
    final position = ref.watch(weatherPositionProvider);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.forestDark,
        title: const Text('Weather outlook'),
        actions: [
          IconButton(
            tooltip: 'Refresh forecast',
            onPressed: () => ref.invalidate(weatherForecastProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: OrganicBackgroundCircles(
        child: forecast.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _accent)),
          error: (error, stackTrace) {
            debugPrint('Weather forecast error: $error');
            return _ForecastError(
              onRetry: () => ref.invalidate(weatherForecastProvider),
            );
          },
          data: (data) => RefreshIndicator(
            color: _accent,
            onRefresh: () async {
              ref.invalidate(weatherForecastProvider);
              await ref.read(weatherForecastProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _CurrentConditions(data: data.current),
                const SizedBox(height: 24),
                const _SectionHeading(
                  title: 'Hourly outlook',
                  trailing: 'NEXT 12 HOURS',
                ),
                const SizedBox(height: 10),
                _HourlyOutlook(hours: data.hourly),
                const SizedBox(height: 24),
                const _SectionHeading(
                  title: '7-day trajectory',
                  trailing: '°C · RAIN CHANCE',
                ),
                const SizedBox(height: 10),
                _SevenDayForecast(days: data.daily),
                const SizedBox(height: 24),
                const _SectionHeading(
                  title: 'Nearby green spaces',
                  trailing: 'NEAREST FIRST',
                ),
                const SizedBox(height: 5),
                Text(
                  data.current.tip,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                _NearbyPlaces(
                  spaces: spaces,
                  position: position,
                  onOpen: (space) => context.push('/navigate', extra: space),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'Weather forecast by Open-Meteo',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentConditions extends StatelessWidget {
  const _CurrentConditions({required this.data});

  final WeatherData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.mintLight, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestDark.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: _accent, size: 16),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  data.placeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const _Pill(
                icon: Icons.cloud_outlined,
                label: 'LIVE WEATHER',
                color: _accent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.tempC.round()}°C',
                      style: const TextStyle(
                        color: AppColors.forestDark,
                        fontSize: 48,
                        height: 1,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      data.description,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(data.icon, color: AppColors.primaryGreen, size: 58),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CurrentStat(
                    icon: Icons.thermostat,
                    label: 'Feels like ${data.feelsLikeC.round()}°',
                  ),
                  const SizedBox(height: 7),
                  _CurrentStat(
                    icon: Icons.water_drop_outlined,
                    label: '${data.humidity}% humidity',
                  ),
                  const SizedBox(height: 7),
                  _CurrentStat(
                    icon: Icons.air,
                    label: '${data.windKmh.round()} km/h wind',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.mintLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_outlined, color: _accent, size: 16),
                const SizedBox(width: 7),
                const Text(
                  'UV INDEX',
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
                const Spacer(),
                Text(
                  data.uvIndex.toStringAsFixed(0),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
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

class _HourlyOutlook extends StatelessWidget {
  const _HourlyOutlook({required this.hours});

  final List<WeatherHour> hours;

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty) {
      return const _EmptyForecast(message: 'Hourly forecast is unavailable.');
    }
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final hour = hours[index];
          return Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 7),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _hourLabel(hour.time),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                Icon(hour.icon, color: _accent, size: 21),
                Text(
                  '${hour.temperatureC.round()}°',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${hour.precipitationProbability}% rain',
                  style: const TextStyle(color: _muted, fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SevenDayForecast extends StatelessWidget {
  const _SevenDayForecast({required this.days});

  final List<WeatherDay> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const _EmptyForecast(message: 'Daily forecast is unavailable.');
    }
    return SizedBox(
      height: 138,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = days[index];
          return Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dayLabel(day.date, index),
                  style: TextStyle(
                    color: index == 0 ? _accent : _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(day.icon, color: AppColors.primaryGreen, size: 22),
                Text(
                  '${day.highC.round()}° / ${day.lowC.round()}°',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${day.precipitationProbability}% rain',
                  style: const TextStyle(color: _muted, fontSize: 9),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NearbyPlaces extends StatelessWidget {
  const _NearbyPlaces({
    required this.spaces,
    required this.position,
    required this.onOpen,
  });

  final AsyncValue<List<GreenSpace>> spaces;
  final AsyncValue<Position?> position;
  final ValueChanged<GreenSpace> onOpen;

  @override
  Widget build(BuildContext context) {
    return spaces.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: _accent)),
      ),
      error: (error, stackTrace) {
        debugPrint('Nearby weather places error: $error');
        return const _EmptyForecast(
          message: 'Nearby green spaces are unavailable right now.',
        );
      },
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyForecast(
            message: 'No green spaces are available to suggest yet.',
          );
        }
        final currentPosition = position.hasValue ? position.value : null;
        final originLat = currentPosition?.latitude ?? kRegionLat;
        final originLng = currentPosition?.longitude ?? kRegionLng;
        final sorted = [...items]
          ..sort(
            (a, b) => _distanceFrom(
              a,
              originLat,
              originLng,
            ).compareTo(_distanceFrom(b, originLat, originLng)),
          );
        return Column(
          children: [
            for (final space in sorted.take(4))
              _PlaceCard(
                space: space,
                distanceMeters: currentPosition == null
                    ? null
                    : _distanceFrom(space, originLat, originLng),
                onTap: () => onOpen(space),
              ),
          ],
        );
      },
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.space,
    required this.distanceMeters,
    required this.onTap,
  });

  final GreenSpace space;
  final double? distanceMeters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = space.photoUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: photo == null || photo.isEmpty
                        ? const _PlaceImagePlaceholder()
                        : CachedNetworkImage(
                            imageUrl: photo,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const _PlaceImagePlaceholder(),
                          ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        space.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        space.description?.trim().isNotEmpty == true
                            ? space.description!.trim()
                            : space.categoryLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(
                            Icons.park_outlined,
                            color: _accent,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              space.categoryLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (distanceMeters != null)
                            Text(
                              _formatDistance(distanceMeters!),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(Icons.arrow_forward_ios, color: _muted, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceImagePlaceholder extends StatelessWidget {
  const _PlaceImagePlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    color: _surfaceLight,
    alignment: Alignment.center,
    child: const Icon(Icons.park_outlined, color: _accent),
  );
}

class _CurrentStat extends StatelessWidget {
  const _CurrentStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: _accent, size: 14),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      Text(
        trailing,
        style: const TextStyle(color: _muted, fontSize: 9, letterSpacing: 0.5),
      ),
    ],
  );
}

class _EmptyForecast extends StatelessWidget {
  const _EmptyForecast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Text(message, style: const TextStyle(color: _muted, fontSize: 12)),
  );
}

class _ForecastError extends StatelessWidget {
  const _ForecastError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, color: _muted, size: 42),
          const SizedBox(height: 12),
          const Text(
            'Could not load the weather forecast.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

double _distanceFrom(GreenSpace space, double latitude, double longitude) =>
    Geolocator.distanceBetween(latitude, longitude, space.lat, space.lng);

String _formatDistance(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(1)} km'
    : '${meters.round()} m';

String _hourLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '$hour $period';
}

String _dayLabel(DateTime date, int index) {
  if (index == 0) return 'Today';
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return weekdays[date.weekday - 1];
}
