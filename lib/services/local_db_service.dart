import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/leaderboard_entry.dart';
import '../models/player_profile.dart';

class PendingBestRecord {
  final String playerId;
  final String playerName;
  final int bestScore;
  final DateTime playedAt;

  const PendingBestRecord({
    required this.playerId,
    required this.playerName,
    required this.bestScore,
    required this.playedAt,
  });
}

/// Quản lý SQLite: lưu điểm local, best score theo người chơi, queue sync.
class LocalDbService {
  LocalDbService._();

  static final LocalDbService instance = LocalDbService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'fly_swatter.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE players (
            player_id TEXT PRIMARY KEY,
            player_name TEXT NOT NULL,
            best_score INTEGER NOT NULL DEFAULT 0,
            best_score_played_at TEXT,
            updated_at TEXT NOT NULL,
            needs_sync INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE score_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id TEXT NOT NULL,
            player_name TEXT NOT NULL,
            score INTEGER NOT NULL,
            played_at TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> insertScoreEvent(
    PlayerProfile profile,
    int score,
    DateTime playedAt,
  ) async {
    final db = await database;
    await db.insert('score_events', {
      'player_id': profile.playerId,
      'player_name': profile.playerName,
      'score': score,
      'played_at': playedAt.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Trả về true nếu cần sync bản ghi best lên cloud
  /// (khi có best score mới hoặc đổi tên người chơi với best score đã tồn tại).
  Future<bool> upsertPlayerBest(
    PlayerProfile profile,
    int score,
    DateTime playedAt,
  ) async {
    final db = await database;
    final current = await db.query(
      'players',
      where: 'player_id = ?',
      whereArgs: [profile.playerId],
      limit: 1,
    );

    final nowIso = DateTime.now().toIso8601String();

    if (current.isEmpty) {
      await db.insert('players', {
        'player_id': profile.playerId,
        'player_name': profile.playerName,
        'best_score': score,
        'best_score_played_at': playedAt.toIso8601String(),
        'updated_at': nowIso,
        'needs_sync': 1,
      });
      return true;
    }

    final row = current.first;
    final currentBest = (row['best_score'] as int?) ?? 0;
    final currentName = (row['player_name'] as String?) ?? '';
    final shouldUpdateBest = score > currentBest;
    final hasExistingBest = currentBest > 0;
    final isNameChanged = currentName.trim() != profile.playerName.trim();
    final shouldSync = shouldUpdateBest || (hasExistingBest && isNameChanged);

    await db.update(
      'players',
      {
        'player_name': profile.playerName,
        if (shouldUpdateBest) 'best_score': score,
        if (shouldUpdateBest)
          'best_score_played_at': playedAt.toIso8601String(),
        if (shouldSync) 'needs_sync': 1,
        'updated_at': nowIso,
      },
      where: 'player_id = ?',
      whereArgs: [profile.playerId],
    );

    return shouldSync;
  }

  Future<List<PendingBestRecord>> getPendingBestRecords() async {
    final db = await database;
    final rows = await db.query(
      'players',
      where: 'needs_sync = 1 AND best_score > 0',
      orderBy: 'updated_at ASC',
    );

    return rows.map((row) {
      final playedAtRaw = row['best_score_played_at'] as String?;
      return PendingBestRecord(
        playerId: row['player_id'] as String,
        playerName: row['player_name'] as String,
        bestScore: (row['best_score'] as int?) ?? 0,
        playedAt:
            playedAtRaw == null
                ? DateTime.now()
                : DateTime.tryParse(playedAtRaw) ?? DateTime.now(),
      );
    }).toList();
  }

  Future<PendingBestRecord?> getPendingBestRecordByPlayerId(
    String playerId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'players',
      where: 'player_id = ? AND needs_sync = 1 AND best_score > 0',
      whereArgs: [playerId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final row = rows.first;
    final playedAtRaw = row['best_score_played_at'] as String?;

    return PendingBestRecord(
      playerId: row['player_id'] as String,
      playerName: row['player_name'] as String,
      bestScore: (row['best_score'] as int?) ?? 0,
      playedAt:
          playedAtRaw == null
              ? DateTime.now()
              : DateTime.tryParse(playedAtRaw) ?? DateTime.now(),
    );
  }

  Future<bool> isPlayerNameTaken({
    required String playerName,
    required String excludingPlayerId,
  }) async {
    final db = await database;
    final normalized = playerName.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    final rows = await db.rawQuery(
      '''
      SELECT player_id
      FROM players
      WHERE lower(trim(player_name)) = ?
        AND player_id != ?
      LIMIT 1
      ''',
      [normalized, excludingPlayerId],
    );

    return rows.isNotEmpty;
  }

  Future<void> markPlayerSynced(String playerId) async {
    final db = await database;
    await db.update(
      'players',
      {'needs_sync': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'player_id = ?',
      whereArgs: [playerId],
    );
  }

  Future<List<LeaderboardEntry>> getTop10LocalLeaderboard() async {
    final db = await database;
    final rows = await db.query(
      'players',
      where: 'best_score > 0',
      orderBy: 'best_score DESC, updated_at ASC',
      limit: 10,
    );

    return rows.map((row) {
      final playedAtRaw = row['best_score_played_at'] as String?;
      return LeaderboardEntry(
        playerId: row['player_id'] as String,
        playerName: row['player_name'] as String,
        bestScore: (row['best_score'] as int?) ?? 0,
        playedAt:
            playedAtRaw == null
                ? DateTime.now()
                : DateTime.tryParse(playedAtRaw) ?? DateTime.now(),
      );
    }).toList();
  }
}
