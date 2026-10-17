import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Places the user hearted. Saved on this phone only (not in the database
/// yet), separately for each signed-in user.
class FavoritePlaces {
  FavoritePlaces._();

  static final ValueNotifier<Set<String>> ids =
      ValueNotifier<Set<String>>(<String>{});

  static String get _key =>
      'favorite_places_${Supabase.instance.client.auth.currentUser?.id ?? 'guest'}';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    ids.value = (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  static Future<void> toggle(String placeId) async {
    final next = {...ids.value};
    if (!next.add(placeId)) next.remove(placeId);
    ids.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }
}
