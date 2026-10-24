import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/json_cache.dart';
import '../../../core/services/location_service.dart';
import '../domain/green_space.dart';
import 'green_space_repository.dart';

/// Serves the green space list (network first, phone copy second), which is
/// why the map, Home and the geofence still work offline.
final greenSpacesProvider = FutureProvider<List<GreenSpace>>(
  (ref) => ref.watch(greenSpaceRepositoryProvider).fetchAll(),
);

final greenSpaceRepositoryProvider = Provider<GreenSpaceRepository>(
  (ref) => GreenSpaceRepository(
    Supabase.instance.client,
    ref.watch(jsonCacheProvider),
  ),
);

/// The user's current position (null if unavailable).
final userPositionProvider = FutureProvider<Position?>(
  (ref) => LocationService.currentPosition(),
);
