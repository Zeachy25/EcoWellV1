import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline/offline_database.dart';
import '../domain/queued_visit.dart';

/// Reads and writes the `offline_visits` table: the phone's copy of visits
/// that Supabase has not seen yet (or is only half-way through).
class OfflineVisitStore {
  OfflineVisitStore(this._offline);
  final OfflineDatabase _offline;

  static const _table = 'offline_visits';

  /// The visit that is still open for this user, if any.
  Future<QueuedVisit?> active(String userId) async {
    final rows = await _rows(where: 'user_id = ? AND status = ?', whereArgs: [
      userId,
      QueuedVisitStatus.inProgress.name,
    ]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<QueuedVisit?> find(String id) async {
    final rows = await _rows(where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Rows still waiting to reach the server, oldest first.
  Future<List<QueuedVisit>> pending(String userId) async {
    final rows = await _rows(
      where: 'user_id = ? AND status != ?',
      whereArgs: [userId, QueuedVisitStatus.inProgress.name],
      orderBy: 'updated_at',
    );
    return rows.map(_fromRow).toList();
  }

  /// Opens a visit at [placeId], keeping any open visit at another place by
  /// marking it abandoned (the server does the same for online visits).
  Future<QueuedVisit> start({
    required String userId,
    required String placeId,
    required String placeName,
  }) async {
    final db = await _offline.database;
    final open = await active(userId);
    if (open != null) {
      if (open.placeId == placeId) return open;
      await abandon(open.id);
    }
    final visit = QueuedVisit(
      id: _newId(),
      userId: userId,
      placeId: placeId,
      placeName: placeName,
      entryTime: DateTime.now(),
      status: QueuedVisitStatus.inProgress,
    );
    await db.insert(_table, _toRow(visit));
    return visit;
  }

  Future<void> savePre(String id, List<int> answers) =>
      _update(id, {'pre_answers': _encodeAnswers(answers)});

  Future<void> finish(String id, List<int> answers, int quietRating) {
    return _update(id, {
      'post_answers': _encodeAnswers(answers),
      'quiet_rating': quietRating,
      'status': QueuedVisitStatus.pendingSync.name,
    });
  }

  Future<void> abandon(String id) =>
      _update(id, {'status': QueuedVisitStatus.abandoned.name});

  /// Records the Supabase id once the visit row has been created there.
  Future<void> attachServerId(String id, String serverVisitId) =>
      _update(id, {'server_visit_id': serverVisitId});

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
    required String where,
    required List<Object?> whereArgs,
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

  Map<String, Object?> _toRow(QueuedVisit v) => {
        'id': v.id,
        'user_id': v.userId,
        'place_id': v.placeId,
        'place_name': v.placeName,
        'server_visit_id': v.serverVisitId,
        'entry_time': v.entryTime.toUtc().millisecondsSinceEpoch,
        'pre_answers': v.preAnswers == null ? null : _encodeAnswers(v.preAnswers!),
        'post_answers':
            v.postAnswers == null ? null : _encodeAnswers(v.postAnswers!),
        'quiet_rating': v.quietRating,
        'status': v.status.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

  QueuedVisit _fromRow(Map<String, Object?> row) => QueuedVisit(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        placeId: row['place_id'] as String,
        placeName: row['place_name'] as String,
        serverVisitId: row['server_visit_id'] as String?,
        entryTime: DateTime.fromMillisecondsSinceEpoch(
          row['entry_time'] as int,
          isUtc: true,
        ).toLocal(),
        preAnswers: _decodeAnswers(row['pre_answers'] as String?),
        postAnswers: _decodeAnswers(row['post_answers'] as String?),
        quietRating: row['quiet_rating'] as int?,
        status: QueuedVisitStatus.values.byName(row['status'] as String),
      );

  static String _encodeAnswers(List<int> answers) =>
      answers.join(',');

  static List<int>? _decodeAnswers(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(',');
    if (parts.length != 4) return null;
    return [for (final p in parts) int.tryParse(p) ?? 0];
  }

  static String _newId() {
    final rand = Random.secure();
    final suffix = rand.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'local-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }
}

final offlineVisitStoreProvider = Provider<OfflineVisitStore>(
  (ref) => OfflineVisitStore(OfflineDatabase.instance),
);
