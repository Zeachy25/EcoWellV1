import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../map/data/map_providers.dart';
import 'geofence_service.dart';

final geofenceServiceProvider = Provider<GeofenceService>((ref) {
  final service = GeofenceService(
    loadSpaces: () => ref.read(greenSpacesProvider.future),
  );
  ref.onDispose(service.dispose);
  return service;
});
