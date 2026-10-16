import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Makes sure location is on and allowed (asks the user if needed).
  static Future<bool> ensurePermission() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('Location permission error: $e');
      return false;
    }
  }

  /// Returns the user's current position, or null when location is off,
  /// permission is denied, or it takes too long.
  static Future<Position?> currentPosition() async {
    try {
      if (!await ensurePermission()) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }
}
