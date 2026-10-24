import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The app's local SQLite database. Tables:
///
/// * `cache_entries` - JSON snapshots of server responses, so screens can
///   still open without a connection (green spaces, profile, dashboard...).
/// * `offline_visits` - visits recorded while offline, waiting to be sent
///   to Supabase (see `OfflineVisitStore` in the visit feature).
/// * `offline_runs` - Quick Runs (GPS walks/runs): checkpoints while a run
///   is going, then the finished runs that sync later (see `RunStore`).
class OfflineDatabase {
  OfflineDatabase._();
  static final OfflineDatabase instance = OfflineDatabase._();

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'ecowell.db'),
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE cache_entries (
            key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE offline_visits (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            place_id TEXT NOT NULL,
            place_name TEXT NOT NULL,
            server_visit_id TEXT,
            entry_time INTEGER NOT NULL,
            pre_answers TEXT,
            post_answers TEXT,
            quiet_rating INTEGER,
            status TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute(_offlineRunsSql);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(_offlineRunsSql);
        }
      },
    );
  }

  static const _offlineRunsSql = '''
          CREATE TABLE IF NOT EXISTS offline_runs (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            activity_type TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            ended_at INTEGER NOT NULL,
            distance_m REAL NOT NULL DEFAULT 0,
            duration_s INTEGER NOT NULL DEFAULT 0,
            path TEXT NOT NULL DEFAULT '[]',
            status TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''';

  /// Removes everything. Called when a different concern needs a clean slate
  /// (for example personal cache entries when the user logs out).
  Future<void> clearCache(Iterable<String> keys) async {
    final db = await database;
    await db.delete(
      'cache_entries',
      where: 'key IN (${List.filled(keys.length, '?').join(',')})',
      whereArgs: keys.toList(),
    );
  }

  /// Removes cache entries whose key starts with one of [prefixes]
  /// (for example "user_profile:" when the user logs out).
  Future<void> clearCacheByPrefix(Iterable<String> prefixes) async {
    final clauses = prefixes.map((_) => 'key LIKE ?').join(' OR ');
    if (clauses.isEmpty) return;
    final db = await database;
    await db.delete(
      'cache_entries',
      where: clauses,
      whereArgs: [for (final p in prefixes) '$p%'],
    );
  }
}
