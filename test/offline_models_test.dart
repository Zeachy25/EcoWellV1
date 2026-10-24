import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:ecowell/core/constants/pss4.dart';
import 'package:ecowell/features/map/domain/green_space.dart';
import 'package:ecowell/features/visit/domain/queued_visit.dart';
import 'package:ecowell/features/weather/domain/weather_models.dart';

void main() {
  group('PSS-4 scoring', () {
    test('items 2 and 3 are reverse-scored', () {
      expect(pss4Total([0, 0, 0, 0]), 8);
      expect(pss4Total([4, 4, 4, 4]), 8);
      expect(pss4Total([4, 0, 0, 4]), 16); // the most stressed answers
      expect(pss4Total([0, 4, 4, 0]), 0); // the calmest answers
    });
  });

  group('WeatherData cache', () {
    test('survives a save and reload', () {
      const original = WeatherData(
        tempC: 31.5,
        feelsLikeC: 34.2,
        humidity: 70,
        windKmh: 12.4,
        uvIndex: 9,
        precipitationMm: 0,
        code: 1,
        isDay: true,
        placeLabel: 'Quezon City, Metro Manila',
      );
      final restored = WeatherData.fromJson(original.toJson());

      expect(restored.tempC, original.tempC);
      expect(restored.humidity, original.humidity);
      expect(restored.code, original.code);
      expect(restored.isDay, original.isDay);
      expect(restored.placeLabel, original.placeLabel);
      expect(restored.description, original.description);
    });
  });

  group('GreenSpace', () {
    test('reads a GeoJSON boundary as [lng, lat] pairs', () {
      final space = GreenSpace.fromJson({
        'id': 'p1',
        'name': 'Test Park',
        'lat': 14.6,
        'lng': 121.0,
        'boundary_geojson': {
          'type': 'Polygon',
          'coordinates': [
            [
              [121.0, 14.6],
              [121.01, 14.6],
              [121.01, 14.61],
              [121.0, 14.6],
            ],
          ],
        },
      });

      expect(space.boundary, hasLength(4));
      expect(space.boundary.first, const LatLng(14.6, 121.0));
      expect(space.boundary.last, const LatLng(14.6, 121.0));
      expect(space.name, 'Test Park');
    });
  });

  group('QueuedVisit', () {
    test('copyWith keeps the phone id, place and answers already saved', () {
      final visit = QueuedVisit(
        id: 'local-1',
        userId: 'u1',
        placeId: 'p1',
        placeName: 'Test Park',
        entryTime: DateTime.utc(2026, 10, 18, 2),
        status: QueuedVisitStatus.inProgress,
        preAnswers: const [3, 1, 0, 2],
      );

      final finished = visit.copyWith(
        postAnswers: const [1, 3, 3, 0],
        quietRating: 4,
        status: QueuedVisitStatus.pendingSync,
      );

      expect(finished.id, 'local-1');
      expect(finished.placeName, 'Test Park');
      expect(finished.preAnswers, const [3, 1, 0, 2]);
      expect(finished.quietRating, 4);
      expect(finished.isFinished, isTrue);
      expect(visit.isFinished, isFalse);
    });
  });
}
