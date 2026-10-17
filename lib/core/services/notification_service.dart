import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/map/domain/green_space.dart';

/// Shows phone notifications (for example "You have arrived at ...") and
/// reports taps back to the app.
///
/// Written for flutter_local_notifications 22.x (named parameters).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  final StreamController<String> _taps = StreamController<String>.broadcast();

  /// Payloads of notifications the user tapped: "arrival:<placeId>" or
  /// "exit:<placeId>".
  Stream<String> get taps => _taps.stream;

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _taps.add(payload);
      },
    );
    _ready = true;
  }

  /// Android 13+ asks the user for permission. Returns true if allowed.
  Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (e) {
      debugPrint('Notification permission error: $e');
      return false;
    }
  }

  static const _arrivalDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'arrivals',
      'Arrival alerts',
      channelDescription:
          'Tells you when EcoWell detects that you arrived at a green space.',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  int _idFor(GreenSpace s) => s.id.hashCode & 0x7fffffff;

  Future<void> showArrival(GreenSpace space) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _idFor(space),
        title: 'You have arrived at ${space.name}',
        body: 'Tap to start your check-in.',
        notificationDetails: _arrivalDetails,
        payload: 'arrival:${space.id}',
      );
    } catch (e) {
      debugPrint('Could not show arrival notification: $e');
    }
  }

  Future<void> showExit(GreenSpace space) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _idFor(space),
        title: 'Leaving ${space.name}?',
        body: 'Tap to finish your visit and see your Stress Reduction Score.',
        notificationDetails: _arrivalDetails,
        payload: 'exit:${space.id}',
      );
    } catch (e) {
      debugPrint('Could not show exit notification: $e');
    }
  }

  /// Removes EcoWell's alerts from the notification shade.
  Future<void> cancelAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Could not clear notifications: $e');
    }
  }
}
