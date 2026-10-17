import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/constants/region.dart';
import '../../../core/services/location_service.dart';
import '../../weather/data/weather_service.dart';
import '../../weather/domain/weather_models.dart';

/// The phone's position if location is already allowed (never asks).
final homePositionProvider = FutureProvider.autoDispose<Position?>(
  (ref) => LocationService.positionIfPermitted(),
);

/// Current weather for the user's position, or for the study area when the
/// position is not available. ref.invalidate(homePositionProvider) refreshes it.
final weatherProvider = FutureProvider.autoDispose<WeatherData>((ref) async {
  final pos = await ref.watch(homePositionProvider.future);
  final service = WeatherService();
  if (pos == null) {
    return service.fetch(lat: kRegionLat, lng: kRegionLng, label: kRegionLabel);
  }
  return service.fetch(lat: pos.latitude, lng: pos.longitude);
});
