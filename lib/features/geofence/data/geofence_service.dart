import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';

import '../../../core/services/location_service.dart';
import '../../map/domain/geo_utils.dart';
import '../../map/domain/green_space.dart';

enum GeofenceEventType { entered, exited }

class GeofenceEvent {
  const GeofenceEvent(this.type, this.space);
  final GeofenceEventType type;
  final GreenSpace space;
}

/// Watches the user's position and tells the app when they ENTER a green
/// space (start the check-in) or have LEFT the place of an open visit
/// (finish the visit).
///
/// On Android it runs as a foreground service (a small ongoing notification),
/// so it keeps working while the app is minimized or the screen is off.
class GeofenceService {
  GeofenceService({required this.loadSpaces});

  final Future<List<GreenSpace>> Function() loadSpaces;

  // ---- tuning ----
  static const _enterTolerance = 10.0; // m outside the edge that still counts
  static const _exitDistance = 40.0; // m outside the edge = really left
  static const _maxAccuracy = 40.0; // ignore GPS readings worse than this (m)
  static const _enterDwell = Duration(seconds: 10); // stay inside this long
  static const _exitDwell = Duration(minutes: 2); // stay outside this long

  final _controller = StreamController<GeofenceEvent>.broadcast();
  Stream<GeofenceEvent> get events => _controller.stream;

  StreamSubscription<Position>? _sub;
  List<GreenSpace> _spaces = const [];

  final Map<String, DateTime> _insideSince = {};
  final Set<String> _triggered = {};
  DateTime? _outsideSince;
  bool _exitEmitted = false;
  String? _activePlaceId;

  bool get isRunning => _sub != null;

  /// Starts watching. Returns false when location is off or not allowed.
  Future<bool> start() async {
    if (_sub != null) return true;
    if (!await LocationService.ensurePermission()) return false;

    try {
      _spaces = await loadSpaces();
    } catch (e) {
      debugPrint('Geofence: could not load places: $e');
      return false;
    }

    _sub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'EcoWell is on',
          notificationText:
              'Watching for green spaces so your check-in can start when you arrive.',
          enableWakeLock: true,
        ),
      ),
    ).listen(
      _onPosition,
      onError: (Object e) => debugPrint('Geofence position error: $e'),
    );
    return true;
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _insideSince.clear();
    _triggered.clear();
    _outsideSince = null;
    _exitEmitted = false;
  }

  /// Tell the service which place has an open visit (null = none).
  void setActivePlace(String? placeId) {
    _activePlaceId = placeId;
    _outsideSince = null;
    _exitEmitted = false;
  }

  /// Call when a visit is finished or cancelled.
  void onVisitClosed() => setActivePlace(null);

  /// For testing from home: pretends the user just entered [space].
  void simulateArrival(GreenSpace space) {
    _triggered.add(space.id);
    _activePlaceId = space.id;
    _controller.add(GeofenceEvent(GeofenceEventType.entered, space));
  }

  void _onPosition(Position p) {
    if (p.accuracy > _maxAccuracy) return;
    final now = DateTime.now();

    for (final s in _spaces) {
      final d = distanceToGeofence(p, s);

      if (d <= _enterTolerance) {
        // Inside (or right at the edge)
        final since = _insideSince.putIfAbsent(s.id, () => now);

        if (_activePlaceId == s.id) {
          _outsideSince = null;
          _exitEmitted = false;
        }

        final readyToTrigger = _activePlaceId == null &&
            !_triggered.contains(s.id) &&
            now.difference(since) >= _enterDwell;
        if (readyToTrigger) {
          _triggered.add(s.id);
          _activePlaceId = s.id;
          _controller.add(GeofenceEvent(GeofenceEventType.entered, s));
        }
      } else if (d > _exitDistance) {
        // Clearly outside
        _insideSince.remove(s.id);
        _triggered.remove(s.id);

        if (_activePlaceId == s.id) {
          _outsideSince ??= now;
          if (!_exitEmitted && now.difference(_outsideSince!) >= _exitDwell) {
            _exitEmitted = true;
            _controller.add(GeofenceEvent(GeofenceEventType.exited, s));
          }
        }
      }
      // Between the two distances: do nothing (avoids flicker at the edge).
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
