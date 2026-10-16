import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/location_service.dart';
import '../domain/green_space.dart';
import 'green_space_repository.dart';

final greenSpaceRepositoryProvider = Provider<GreenSpaceRepository>(
  (ref) => GreenSpaceRepository(Supabase.instance.client),
);

final greenSpacesProvider = FutureProvider<List<GreenSpace>>(
  (ref) => ref.watch(greenSpaceRepositoryProvider).fetchAll(),
);

/// The user's current position (null if unavailable).
final userPositionProvider = FutureProvider<Position?>(
  (ref) => LocationService.currentPosition(),
);
