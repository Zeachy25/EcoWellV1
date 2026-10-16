import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/ors_config.dart';
import '../domain/route_models.dart';

/// An error with a message that is safe to show to the user.
class RoutingException implements Exception {
  RoutingException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Walking directions from openrouteservice (OpenStreetMap data).
class OrsRoutingService {
  static const _url =
      'https://api.openrouteservice.org/v2/directions/foot-walking/geojson';

  Future<RouteInfo> walkingRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    if (OrsConfig.apiKey.startsWith('YOUR_')) {
      throw RoutingException(
        'In-app directions are not set up yet. '
        'Add your openrouteservice key in lib/core/ors_config.dart.',
      );
    }

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': OrsConfig.apiKey,
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/geo+json',
            },
            body: jsonEncode({
              'coordinates': [
                [from.longitude, from.latitude],
                [to.longitude, to.latitude],
              ],
              'instructions': true,
              'language': 'en',
              'radiuses': [500, 1000],
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('Routing network error: $e');
      throw RoutingException(
        'Could not reach the routing service. Check your connection.',
      );
    }

    if (res.statusCode == 200) {
      try {
        return _parse(utf8.decode(res.bodyBytes));
      } catch (e) {
        debugPrint('Routing parse error: $e');
        throw RoutingException('Could not read the route. Please try again.');
      }
    }

    debugPrint('Routing error ${res.statusCode}: ${res.body}');
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw RoutingException(
        'The routing key is not valid. Check lib/core/ors_config.dart.',
      );
    }
    if (res.statusCode == 429) {
      throw RoutingException(
        'Too many route requests right now. Please try again in a minute.',
      );
    }

    int? code;
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final err = body is Map ? body['error'] : null;
      if (err is Map && err['code'] is num) code = (err['code'] as num).toInt();
    } catch (_) {}

    if (code == 2010) {
      throw RoutingException('No walking route was found near here.');
    }
    if (code == 2004) {
      throw RoutingException('This place is too far for walking directions.');
    }
    throw RoutingException('Could not get directions right now.');
  }

  RouteInfo _parse(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final feature = (data['features'] as List).first as Map<String, dynamic>;

    final coords = (feature['geometry'] as Map<String, dynamic>)['coordinates']
        as List<dynamic>;
    final points = [
      for (final c in coords)
        LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];

    final props = feature['properties'] as Map<String, dynamic>;
    final summary = props['summary'] as Map<String, dynamic>;

    final steps = <RouteStep>[];
    for (final seg in (props['segments'] as List<dynamic>? ?? const [])) {
      for (final s in (seg['steps'] as List<dynamic>? ?? const [])) {
        final wp =
            (s['way_points'] as List<dynamic>).map((e) => (e as num).toInt()).toList();
        steps.add(RouteStep(
          instruction: (s['instruction'] as String?) ?? '',
          distance: (s['distance'] as num).toDouble(),
          duration: (s['duration'] as num).toDouble(),
          type: (s['type'] as num?)?.toInt() ?? 6,
          name: s['name'] as String?,
          startIndex: wp[0],
          endIndex: wp[1],
        ));
      }
    }

    return RouteInfo(
      points: points,
      distanceMeters: (summary['distance'] as num).toDouble(),
      durationSeconds: (summary['duration'] as num).toDouble(),
      steps: steps,
    );
  }
}
