import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class GreenSpace {
  const GreenSpace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.boundary,
    this.description,
    this.category,
    this.photoUrl,
    this.quietScoreAvg,
    this.quietRatingCount = 0,
  });

  final String id;
  final String name;
  final String? description;
  final String? category;
  final String? photoUrl;
  final double lat;
  final double lng;
  final List<LatLng> boundary;
  final double? quietScoreAvg;
  final int quietRatingCount;

  factory GreenSpace.fromJson(Map<String, dynamic> json) {
    return GreenSpace(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      photoUrl: json['photo_url'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      boundary: _parseBoundary(json['boundary_geojson']),
      quietScoreAvg: (json['quiet_score_avg'] as num?)?.toDouble(),
      quietRatingCount: (json['quiet_rating_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// GeoJSON Polygon -> list of LatLng (outer ring). GeoJSON order is [lng, lat].
  static List<LatLng> _parseBoundary(dynamic geo) {
    if (geo is String) geo = jsonDecode(geo);
    if (geo is! Map) return const [];
    final coords = geo['coordinates'];
    if (coords is! List || coords.isEmpty) return const [];
    final ring = coords.first;
    if (ring is! List) return const [];
    return [
      for (final p in ring)
        LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
    ];
  }

  /// Smallest box that contains the whole boundary (used to zoom the map).
  LatLngBounds get bounds {
    if (boundary.isEmpty) {
      return LatLngBounds(
        southwest: LatLng(lat - 0.001, lng - 0.001),
        northeast: LatLng(lat + 0.001, lng + 0.001),
      );
    }
    var minLat = boundary.first.latitude;
    var maxLat = minLat;
    var minLng = boundary.first.longitude;
    var maxLng = minLng;
    for (final p in boundary) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  String get categoryLabel {
    final c = category;
    if (c == null || c.isEmpty) return 'Green space';
    return c[0].toUpperCase() + c.substring(1);
  }
}
