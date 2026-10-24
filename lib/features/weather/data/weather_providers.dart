import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/region.dart';
import '../../../core/offline/json_cache.dart';
import '../../../core/services/location_service.dart';
import '../domain/weather_models.dart';
import 'weather_service.dart';

/// The phone's position if location is already allowed (never asks).
final weatherPositionProvider = FutureProvider.autoDispose<Position?>(
  (ref) => LocationService.positionIfPermitted(),
);

/// Current weather for the user's position, or the configured study area.
/// The last reading is cached locally for offline Home.
final weatherProvider = FutureProvider.autoDispose<WeatherData>((ref) async {
  final cache = ref.watch(jsonCacheProvider);
  final position = await ref.watch(weatherPositionProvider.future);
  final service = WeatherService();
  try {
    final data = position == null
        ? await service.fetch(
            lat: kRegionLat,
            lng: kRegionLng,
            label: kRegionLabel,
          )
        : await service.fetch(lat: position.latitude, lng: position.longitude);
    await cache.write(CacheKeys.weather, data.toJson());
    return data;
  } catch (error) {
    final cached = await cache.read(CacheKeys.weather);
    if (cached is Map) {
      return WeatherData.fromJson(Map<String, dynamic>.from(cached));
    }
    rethrow;
  }
});

/// Current, hourly, and seven-day conditions for the user's location.
final weatherForecastProvider = FutureProvider.autoDispose<WeatherForecast>((
  ref,
) async {
  final position = await ref.watch(weatherPositionProvider.future);
  final service = WeatherService();
  return position == null
      ? service.fetchForecast(
          lat: kRegionLat,
          lng: kRegionLng,
          label: kRegionLabel,
        )
      : service.fetchForecast(lat: position.latitude, lng: position.longitude);
});
