import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'green_space.dart';

/// Ray-casting test: is the point inside the polygon?
bool pointInPolygon(double lat, double lng, List<LatLng> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final yi = poly[i].latitude, xi = poly[i].longitude;
    final yj = poly[j].latitude, xj = poly[j].longitude;
    final crosses = ((yi > lat) != (yj > lat)) &&
        (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi);
    if (crosses) inside = !inside;
  }
  return inside;
}

/// Meters from the point to the polygon's edge (0 when inside).
double distanceToPolygonMeters(double lat, double lng, List<LatLng> poly) {
  if (poly.length < 3) return double.infinity;
  if (pointInPolygon(lat, lng, poly)) return 0;

  // Flat (local) meters around the point: fine for short distances.
  const mLat = 110540.0;
  final mLng = 111320.0 * math.cos(lat * math.pi / 180);

  var best = double.infinity;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i];
    final b = poly[(i + 1) % poly.length];
    final ax = (a.longitude - lng) * mLng;
    final ay = (a.latitude - lat) * mLat;
    final bx = (b.longitude - lng) * mLng;
    final by = (b.latitude - lat) * mLat;
    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final px = ax + t * dx;
    final py = ay + t * dy;
    final d = math.sqrt(px * px + py * py);
    if (d < best) best = d;
  }
  return best;
}

/// Meters from the position to the place's geofence (0 when inside).
/// Places without a boundary use a 50 m circle around their center.
double distanceToGeofence(Position pos, GreenSpace s) {
  if (s.boundary.length >= 3) {
    return distanceToPolygonMeters(pos.latitude, pos.longitude, s.boundary);
  }
  final d =
      Geolocator.distanceBetween(pos.latitude, pos.longitude, s.lat, s.lng);
  return math.max(0.0, d - 50);
}

/// True when the position is inside the geofence, or within a few meters
/// of its edge (GPS under trees can drift).
bool isInsideGeofence(Position pos, GreenSpace s, {double tolerance = 10}) {
  return distanceToGeofence(pos, s) <= tolerance;
}
