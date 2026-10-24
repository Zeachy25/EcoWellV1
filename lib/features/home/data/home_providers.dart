import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/region.dart';
import '../../../core/offline/json_cache.dart';
import '../../../core/services/location_service.dart';
import '../../weather/data/weather_service.dart';
import '../../weather/domain/weather_models.dart';

/// The phone's position if location is already allowed (never asks).
final homePositionProvider = FutureProvider.autoDispose<Position?>(
  (ref) => LocationService.positionIfPermitted(),
);

/// Current weather for the user's position, or for the study area when the
/// position is not available. ref.invalidate(homePositionProvider) refreshes it.
///
/// The last reading is kept on the phone, so Home can still show the weather
/// card inside a park with no signal.
final weatherProvider = FutureProvider.autoDispose<WeatherData>((ref) async {
  final cache = ref.watch(jsonCacheProvider);
  final pos = await ref.watch(homePositionProvider.future);
  final service = WeatherService();
  try {
    final data = pos == null
        ? await service.fetch(lat: kRegionLat, lng: kRegionLng, label: kRegionLabel)
        : await service.fetch(lat: pos.latitude, lng: pos.longitude);
    await cache.write(CacheKeys.weather, data.toJson());
    return data;
  } catch (e) {
    final cached = await cache.read(CacheKeys.weather);
    if (cached is Map) {
      return WeatherData.fromJson(Map<String, dynamic>.from(cached));
    }
    rethrow;
  }
});
