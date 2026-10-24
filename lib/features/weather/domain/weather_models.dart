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
    return weatherDescription(code, isDay: isDay);
  }

  IconData get icon {
    return weatherIcon(code, isDay: isDay);
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

class WeatherHour {
  const WeatherHour({
    required this.time,
    required this.temperatureC,
    required this.code,
    required this.precipitationProbability,
    required this.uvIndex,
  });

  final DateTime time;
  final double temperatureC;
  final int code;
  final int precipitationProbability;
  final double uvIndex;

  factory WeatherHour.fromJson(Map<String, dynamic> json) => WeatherHour(
    time: DateTime.parse(json['time'] as String),
    temperatureC: (json['temperature_2m'] as num).toDouble(),
    code: (json['weather_code'] as num).toInt(),
    precipitationProbability:
        (json['precipitation_probability'] as num?)?.toInt() ?? 0,
    uvIndex: (json['uv_index'] as num?)?.toDouble() ?? 0,
  );

  String get description => weatherDescription(code);
  IconData get icon => weatherIcon(code);
}

class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.highC,
    required this.lowC,
    required this.code,
    required this.precipitationProbability,
    required this.maxUvIndex,
  });

  final DateTime date;
  final double highC;
  final double lowC;
  final int code;
  final int precipitationProbability;
  final double maxUvIndex;

  factory WeatherDay.fromJson(Map<String, dynamic> json) => WeatherDay(
    date: DateTime.parse(json['time'] as String),
    highC: (json['temperature_2m_max'] as num).toDouble(),
    lowC: (json['temperature_2m_min'] as num).toDouble(),
    code: (json['weather_code'] as num).toInt(),
    precipitationProbability:
        (json['precipitation_probability_max'] as num?)?.toInt() ?? 0,
    maxUvIndex: (json['uv_index_max'] as num?)?.toDouble() ?? 0,
  );

  String get description => weatherDescription(code);
  IconData get icon => weatherIcon(code);
}

String weatherDescription(int code, {bool isDay = true}) {
  if (code == 0) return isDay ? 'Clear sky' : 'Clear night';
  if (code == 1) return 'Mostly clear';
  if (code == 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Fog';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Rain showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Cloudy';
}

IconData weatherIcon(int code, {bool isDay = true}) {
  if (code == 0 || code == 1) {
    return isDay ? Icons.wb_sunny : Icons.nightlight_round;
  }
  if (code == 2) return Icons.wb_cloudy;
  if (code == 3) return Icons.cloud;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 95) return Icons.thunderstorm;
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return Icons.water_drop;
  }
  return Icons.cloud;
}

class WeatherForecast {
  const WeatherForecast({
    required this.current,
    required this.hourly,
    required this.daily,
  });

  final WeatherData current;
  final List<WeatherHour> hourly;
  final List<WeatherDay> daily;

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final current = Map<String, dynamic>.from(json['current'] as Map);
    final hourly = Map<String, dynamic>.from(json['hourly'] as Map);
    final daily = Map<String, dynamic>.from(json['daily'] as Map);

    List<Map<String, dynamic>> rows(
      Map<String, dynamic> values,
      List<String> keys,
    ) {
      final arrays = <String, List<dynamic>>{};
      for (final key in keys) {
        final value = values[key];
        if (value is! List) {
          throw FormatException('Weather response is missing "$key".');
        }
        arrays[key] = value;
      }
      final length = arrays.values.first.length;
      if (arrays.values.any((array) => array.length != length)) {
        throw const FormatException(
          'Weather response arrays have different lengths.',
        );
      }
      return [
        for (var index = 0; index < length; index++)
          {for (final key in keys) key: arrays[key]![index]},
      ];
    }

    final hourlyRows = rows(hourly, [
      'time',
      'temperature_2m',
      'weather_code',
      'precipitation_probability',
      'uv_index',
    ]);
    final dailyRows = rows(daily, [
      'time',
      'temperature_2m_max',
      'temperature_2m_min',
      'weather_code',
      'precipitation_probability_max',
      'uv_index_max',
    ]);
    final now = DateTime.now();
    final futureHours = hourlyRows
        .map(WeatherHour.fromJson)
        .where(
          (hour) => hour.time.isAfter(now.subtract(const Duration(hours: 1))),
        )
        .take(12)
        .toList();

    return WeatherForecast(
      current: WeatherData(
        tempC: (current['temperature_2m'] as num).toDouble(),
        feelsLikeC: (current['apparent_temperature'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).toInt(),
        windKmh: (current['wind_speed_10m'] as num).toDouble(),
        uvIndex: (current['uv_index'] as num).toDouble(),
        precipitationMm: (current['precipitation'] as num).toDouble(),
        code: (current['weather_code'] as num).toInt(),
        isDay: (current['is_day'] as num).toInt() == 1,
        placeLabel: json['place_label'] as String? ?? 'Near you',
      ),
      hourly: futureHours,
      daily: dailyRows.map(WeatherDay.fromJson).take(7).toList(),
    );
  }
}
