import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// One instruction, e.g. "Turn left onto Rizal Street".
class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.type,
    required this.startIndex,
    required this.endIndex,
    this.name,
  });

  final String instruction;

  /// Meters from this maneuver to the next one.
  final double distance;
  final double duration;

  /// openrouteservice maneuver code (0 left, 1 right, 6 straight, 10 arrive ...).
  final int type;
  final String? name;

  /// Positions in RouteInfo.points where this step starts and ends.
  final int startIndex;
  final int endIndex;
}

class RouteInfo {
  RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  }) : cumulative = _cumulativeDistances(points);

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;

  /// cumulative[i] = meters from the start of the route to points[i].
  final List<double> cumulative;

  double get polylineLength => cumulative.isEmpty ? 0 : cumulative.last;

  static List<double> _cumulativeDistances(List<LatLng> pts) {
    final out = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      out.add(out.last +
          Geolocator.distanceBetween(
            pts[i - 1].latitude,
            pts[i - 1].longitude,
            pts[i].latitude,
            pts[i].longitude,
          ));
    }
    return out;
  }
}
