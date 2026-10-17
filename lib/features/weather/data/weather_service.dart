import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/weather_models.dart';

/// Current weather from Open-Meteo (free, no key; attribution is shown in
/// the app) and a place name from BigDataCloud's free client-side
/// reverse-geocoding service.
class WeatherService {
  Future<WeatherData> fetch({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final results = await Future.wait<dynamic>([
      _current(lat, lng),
      label != null ? Future<String?>.value(label) : _placeName(lat, lng),
    ]);

    final c = results[0] as Map<String, dynamic>;
    final name = (results[1] as String?) ?? 'Near you';

    double num0(String k) => (c[k] as num?)?.toDouble() ?? 0;

    return WeatherData(
      tempC: num0('temperature_2m'),
      feelsLikeC: num0('apparent_temperature'),
      humidity: (c['relative_humidity_2m'] as num?)?.round() ?? 0,
      windKmh: num0('wind_speed_10m'),
      uvIndex: num0('uv_index'),
      precipitationMm: num0('precipitation'),
      code: (c['weather_code'] as num?)?.toInt() ?? 3,
      isDay: ((c['is_day'] as num?)?.toInt() ?? 1) == 1,
      placeLabel: name,
    );
  }

  Future<Map<String, dynamic>> _current(double lat, double lng) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$lat',
      'longitude': '$lng',
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,'
          'precipitation,weather_code,wind_speed_10m,uv_index,is_day',
      'timezone': 'auto',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Weather request failed (${res.statusCode})');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return Map<String, dynamic>.from(json['current'] as Map);
  }

  /// "City, Region" for the coordinates, or null if it cannot be found.
  Future<String?> _placeName(double lat, double lng) async {
    try {
      final uri = Uri.https(
        'api.bigdatacloud.net',
        '/data/reverse-geocode-client',
        {
          'latitude': '$lat',
          'longitude': '$lng',
          'localityLanguage': 'en',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      String clean(dynamic v) => (v?.toString() ?? '').trim();
      final city = clean(j['city']).isNotEmpty
          ? clean(j['city'])
          : clean(j['locality']);
      final region = clean(j['principalSubdivision']);

      final parts = <String>[
        if (city.isNotEmpty) city,
        if (region.isNotEmpty && region != city) region,
      ];
      return parts.isEmpty ? null : parts.join(', ');
    } catch (e) {
      debugPrint('Place name error: $e');
      return null;
    }
  }
}
