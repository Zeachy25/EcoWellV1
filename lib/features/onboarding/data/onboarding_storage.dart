import 'package:shared_preferences/shared_preferences.dart';

/// Remembers (on the device) whether the user already saw the onboarding.
class OnboardingStorage {
  static const _key = 'onboarding_seen';

  static Future<bool> isSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
