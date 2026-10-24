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

  /// True when tracking with the screen off is allowed. Android calls
  /// this "Allow all the time" (LocationPermission.always).
  static Future<bool> hasBackgroundPermission() async {
    try {
      return await Geolocator.checkPermission() ==
          LocationPermission.always;
    } catch (e) {
      debugPrint('Background permission check error: $e');
      return false;
    }
  }

  /// The position ONLY if location is already allowed. Never shows a
  /// permission prompt, so it is safe to call as soon as the Home tab opens.
  static Future<Position?> positionIfPermitted() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      return await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            ),
          );
    } catch (e) {
      debugPrint('Location (no prompt) error: $e');
      return null;
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
