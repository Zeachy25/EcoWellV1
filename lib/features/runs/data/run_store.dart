import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../../core/offline/offline_database.dart';
import '../domain/run_models.dart';

/// Reads and writes the `offline_runs` table: the phone's copy of every
/// Quick Run. While a run is being recorded the row is a checkpoint
/// (`active`); once finished it waits for the network (`pendingSync`) and
/// is finally kept as offline history (`synced`).
class RunStore {
  RunStore(this._offline);
  final OfflineDatabase _offline;

  static const _table = 'offline_runs';

  /// The run that is currently being recorded, if any (used to recover
  /// after the app was killed mid-run).
  Future<RunRecord?> active(String userId) async {
    final rows = await _rows(
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, RunStatus.active.name],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : RunRecord.fromRow(rows.first);
  }

  /// Finished runs for the history list, newest first.
  Future<List<RunRecord>> history(String userId) async {
    final rows = await _rows(
      where: 'user_id = ? AND status != ?',
      whereArgs: [userId, RunStatus.active.name],
      orderBy: 'started_at DESC',
    );
    return rows.map(RunRecord.fromRow).whereType<RunRecord>().toList();
  }

  /// Finished runs still waiting to reach the server, oldest first.
  Future<List<RunRecord>> pendingSync(String userId) async {
    final rows = await _rows(
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, RunStatus.pendingSync.name],
      orderBy: 'started_at',
    );
    return rows.map(RunRecord.fromRow).whereType<RunRecord>().toList();
  }

  /// Inserts or replaces the row with the same id (checkpoint refresh).
  Future<void> save(RunRecord record) async {
    final db = await _offline.database;
    await db.insert(
      _table,
      _toRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The run reached the server; keep the row as offline history.
  Future<void> markSynced(String id) => _update(id, {
        'status': RunStatus.synced.name,
      });

  Future<void> remove(String id) async {
    final db = await _offline.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _update(String id, Map<String, Object?> values) async {
    final db = await _offline.database;
    await db.update(
      _table,
      {
        ...values,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> _rows({
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) {
    return _offline.database.then((db) => db.query(
          _table,
          where: where,
          whereArgs: whereArgs,
          orderBy: orderBy,
          limit: limit,
        ));
  }

  Map<String, Object?> _toRow(RunRecord r) => {
        'id': r.id,
        'user_id': r.userId,
        'activity_type': r.type.wire,
        'started_at': r.startedAt.toUtc().millisecondsSinceEpoch,
        'ended_at': r.endedAt.toUtc().millisecondsSinceEpoch,
        'distance_m': r.distanceMeters,
        'duration_s': r.durationSeconds,
        'path': jsonEncode([for (final p in r.path) p.toJson()]),
        'status': r.status.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };
}

final runStoreProvider = Provider<RunStore>(
  (ref) => RunStore(OfflineDatabase.instance),
);
