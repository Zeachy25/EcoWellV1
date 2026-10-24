import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'offline_database.dart';

/// Typed wrapper around the `cache_entries` table: JSON snapshots of server
/// responses together with the time they were saved.
///
/// Repositories write after a successful fetch and read when the network
/// call fails, which is what keeps the app usable without a connection.
class JsonCache {
  JsonCache(this._offline);
  final OfflineDatabase _offline;

  Future<void> write(String key, Object? json) async {
    final db = await _offline.database;
    await db.insert(
      'cache_entries',
      {
        'key': key,
        'json': jsonEncode(json),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The cached value, or null when this key was never saved.
  Future<Object?> read(String key) async {
    final db = await _offline.database;
    final rows = await db.query(
      'cache_entries',
      columns: ['json'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      return jsonDecode(rows.first['json'] as String);
    } catch (_) {
      return null;
    }
  }

  /// When the value was last saved (null if never saved).
  Future<DateTime?> updatedAt(String key) async {
    final db = await _offline.database;
    final rows = await db.query(
      'cache_entries',
      columns: ['updated_at'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final ms = rows.first['updated_at'] as int;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Removes personal snapshots (profile, dashboard, feed, weather, cached
  /// profile pages) when the user signs out. Shared data such as green
  /// spaces stays.
  Future<void> clearPersonal() async {
    await _offline.clearCache(const [
      'profile',
      'dashboard',
      'weather',
      'feed_all',
      'feed_following',
    ]);
    await _offline.clearCacheByPrefix(const ['user_profile:', 'user_posts:']);
  }
}

/// Cache keys used across features, so nothing is misspelled twice.
abstract final class CacheKeys {
  static const profile = 'profile';
  static const dashboard = 'dashboard';
  static const weather = 'weather';
  static const feedAll = 'feed_all';
  static const feedFollowing = 'feed_following';
  static const greenSpaces = 'green_spaces';

  /// Activities are cached per type ("breathing", "grounding").
  static String activities(String type) => 'activities:$type';

  /// Public profile header of one user (cached per id, offline profiles).
  static String userProfile(String uid) => 'user_profile:$uid';

  /// The first page of one user's posts (profile timeline, offline).
  static String userPosts(String uid) => 'user_posts:$uid';

  /// Cached place social counts and the signed-in user's like state.
  static String placeSocial(String uid) => 'place_social:$uid';

  /// Public aggregate counts shared across accounts on this device.
  static const placeSocialCounts = 'place_social_counts';
}

final jsonCacheProvider = Provider<JsonCache>(
  (ref) => JsonCache(OfflineDatabase.instance),
);
