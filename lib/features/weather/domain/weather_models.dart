import 'package:flutter/material.dart';

/// Current weather, from Open-Meteo (weather codes follow the WMO table).
class WeatherData {
  const WeatherData({
    required this.tempC,
    required this.feelsLikeC,
    required this.humidity,
    required this.windKmh,
    required this.uvIndex,
    required this.precipitationMm,
    required this.code,
    required this.isDay,
    required this.placeLabel,
  });

  final double tempC;
  final double feelsLikeC;
  final int humidity;
  final double windKmh;
  final double uvIndex;
  final double precipitationMm;
  final int code;
  final bool isDay;
  final String placeLabel;

  /// Used to keep the last known weather on the phone for offline Home.
  Map<String, dynamic> toJson() => {
        'temp_c': tempC,
        'feels_like_c': feelsLikeC,
        'humidity': humidity,
        'wind_kmh': windKmh,
        'uv_index': uvIndex,
        'precipitation_mm': precipitationMm,
        'code': code,
        'is_day': isDay,
        'place_label': placeLabel,
      };

  factory WeatherData.fromJson(Map<String, dynamic> j) => WeatherData(
        tempC: (j['temp_c'] as num?)?.toDouble() ?? 0,
        feelsLikeC: (j['feels_like_c'] as num?)?.toDouble() ?? 0,
        humidity: (j['humidity'] as num?)?.toInt() ?? 0,
        windKmh: (j['wind_kmh'] as num?)?.toDouble() ?? 0,
        uvIndex: (j['uv_index'] as num?)?.toDouble() ?? 0,
        precipitationMm: (j['precipitation_mm'] as num?)?.toDouble() ?? 0,
        code: (j['code'] as num?)?.toInt() ?? 3,
        isDay: (j['is_day'] as bool?) ?? true,
        placeLabel: (j['place_label'] as String?) ?? 'Near you',
      );

  String get description {
    final c = code;
    if (c == 0) return isDay ? 'Clear sky' : 'Clear night';
    if (c == 1) return 'Mostly clear';
    if (c == 2) return 'Partly cloudy';
    if (c == 3) return 'Overcast';
    if (c == 45 || c == 48) return 'Fog';
    if (c >= 51 && c <= 57) return 'Drizzle';
    if (c >= 61 && c <= 67) return 'Rain';
    if (c >= 71 && c <= 77) return 'Snow';
    if (c >= 80 && c <= 82) return 'Rain showers';
    if (c >= 95) return 'Thunderstorm';
    return 'Cloudy';
  }

  IconData get icon {
    final c = code;
    if (c == 0 || c == 1) return isDay ? Icons.wb_sunny : Icons.nightlight_round;
    if (c == 2) return Icons.wb_cloudy;
    if (c == 3) return Icons.cloud;
    if (c == 45 || c == 48) return Icons.foggy;
    if (c >= 95) return Icons.thunderstorm;
    if (isWet) return Icons.water_drop;
    return Icons.cloud;
  }

  bool get isWet =>
      (code >= 51 && code <= 67) ||
      (code >= 80 && code <= 82) ||
      code >= 95 ||
      precipitationMm > 0.2;

  /// A short, plain suggestion for going outside.
  String get tip {
    if (code >= 95) {
      return 'Thunderstorms are around. Stay indoors and try a breathing '
          'exercise instead.';
    }
    if (isWet) {
      return 'It is wet outside. Bring an umbrella, or try a breathing '
          'exercise indoors.';
    }
    if (uvIndex >= 8) {
      return 'The UV index is very high. Visit early in the morning or late '
          'in the afternoon, and wear a hat.';
    }
    if (tempC >= 33) {
      return 'It is hot. Bring water and choose a shaded green space.';
    }
    return 'Good conditions for a green space visit. Enjoy your time outside!';
  }
}
