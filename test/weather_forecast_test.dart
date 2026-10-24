import 'package:flutter_test/flutter_test.dart';
import 'package:ecowell/features/weather/domain/weather_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses current conditions, next hours, and seven daily forecasts', () {
    final now = DateTime.now();
    final startOfCurrentHour = DateTime(now.year, now.month, now.day, now.hour);
    final hourlyTimes = [
      for (var hour = 0; hour < 15; hour++)
        startOfCurrentHour.add(Duration(hours: hour)).toIso8601String(),
    ];
    final dailyDates = [
      for (var day = 0; day < 7; day++)
        DateTime(
          now.year,
          now.month,
          now.day,
        ).add(Duration(days: day)).toIso8601String().substring(0, 10),
    ];

    final forecast = WeatherForecast.fromJson({
      'place_label': 'Test City',
      'current': {
        'temperature_2m': 24,
        'apparent_temperature': 25,
        'relative_humidity_2m': 70,
        'wind_speed_10m': 12,
        'uv_index': 3,
        'precipitation': 0,
        'weather_code': 2,
        'is_day': 1,
      },
      'hourly': {
        'time': hourlyTimes,
        'temperature_2m': List<double>.generate(15, (index) => 24 + index / 10),
        'weather_code': List<int>.filled(15, 2),
        'precipitation_probability': List<int>.filled(15, 15),
        'uv_index': List<double>.filled(15, 2),
      },
      'daily': {
        'time': dailyDates,
        'temperature_2m_max': List<int>.generate(7, (index) => 28 + index),
        'temperature_2m_min': List<int>.generate(7, (index) => 20 + index),
        'weather_code': List<int>.filled(7, 2),
        'precipitation_probability_max': List<int>.filled(7, 30),
        'uv_index_max': List<int>.filled(7, 5),
      },
    });

    expect(forecast.current.placeLabel, 'Test City');
    expect(forecast.current.tempC, 24);
    expect(forecast.hourly, hasLength(12));
    expect(forecast.hourly.first.temperatureC, 24);
    expect(forecast.daily, hasLength(7));
    expect(forecast.daily.last.highC, 34);
  });
}
