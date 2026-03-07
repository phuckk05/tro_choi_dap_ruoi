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
      version: 3,
      onCreate: (db, version) async {
        // Bang tong hop best score moi player.
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

        // Bang log tung tran cho thong ke va truy vet du lieu.
        await db.execute('''
          CREATE TABLE score_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id TEXT NOT NULL,
            player_name TEXT NOT NULL,
            score INTEGER NOT NULL,
            defeat_seconds INTEGER,
            -- Giu ten cot cu de tuong thich du lieu da phat hanh.
            secendtiem INTEGER,
            fly_count_at_defeat INTEGER,
            played_at TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE score_events ADD COLUMN defeat_seconds INTEGER',
          );
          await db.execute(
            'ALTER TABLE score_events ADD COLUMN fly_count_at_defeat INTEGER',
          );
        }
        if (oldVersion < 3) {
          // Bo sung cot thoi gian theo schema cu (secendtiem).
          await db.execute(
            'ALTER TABLE score_events ADD COLUMN secendtiem INTEGER',
          );
        }
      },
    );
  }

  Future<void> insertScoreEvent(
    PlayerProfile profile,
    int score,
    DateTime playedAt, {
    int? defeatSeconds,
    int? secendtiem,
    int? flyCountAtDefeat,
  }) async {
    final db = await database;
    await db.insert('score_events', {
      'player_id': profile.playerId,
      'player_name': profile.playerName,
      'score': score,
      'defeat_seconds': defeatSeconds,
      'secendtiem': secendtiem,
      'fly_count_at_defeat': flyCountAtDefeat,
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

    Map<String, Object?> row;
    if (current.isEmpty) {
      final inserted = await db.insert('players', {
        'player_id': profile.playerId,
        'player_name': profile.playerName,
        'best_score': score,
        'best_score_played_at': playedAt.toIso8601String(),
        'updated_at': nowIso,
        'needs_sync': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      if (inserted > 0) {
        return true;
      }

      final existing = await db.query(
        'players',
        where: 'player_id = ?',
        whereArgs: [profile.playerId],
        limit: 1,
      );
      if (existing.isEmpty) return false;
      row = existing.first;
    } else {
      row = current.first;
    }

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

  Future<PendingBestRecord?> getPlayerBestRecordByPlayerId(
    String playerId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'players',
      where: 'player_id = ?',
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

  Future<Map<String, int>> getLatestSecendtiemByPlayerIds(
    List<String> playerIds,
  ) async {
    // Lay thoi gian lon nhat moi player de dong bo voi leaderboard.
    if (playerIds.isEmpty) return const {};

    final db = await database;
    final placeholders = List.filled(playerIds.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT player_id, MAX(COALESCE(secendtiem, defeat_seconds, 0)) AS secendtiem
      FROM score_events
      WHERE player_id IN ($placeholders)
      GROUP BY player_id
      ''', playerIds);

    final result = <String, int>{};
    for (final row in rows) {
      final playerId = row['player_id']?.toString();
      if (playerId == null) continue;

      final secendtiemRaw = row['secendtiem'];
      final secendtiem =
          secendtiemRaw is int
              ? secendtiemRaw
              : int.tryParse(secendtiemRaw?.toString() ?? '');
      if (secendtiem == null) continue;

      result[playerId] = secendtiem;
    }

    return result;
  }

  Future<List<LeaderboardEntry>> getLocalLeaderboard() async {
    final db = await database;
    final rows = await db.query(
      'players',
      where: 'best_score > 0',
      orderBy: 'updated_at DESC',
    );

    final playerIds = rows.map((row) => row['player_id'] as String).toList();
    final durationByPlayer = await getLatestSecendtiemByPlayerIds(playerIds);

    final entries =
        rows.map((row) {
          final playedAtRaw = row['best_score_played_at'] as String?;
          final playerId = row['player_id'] as String;
          return LeaderboardEntry(
            playerId: playerId,
            playerName: row['player_name'] as String,
            bestScore: (row['best_score'] as int?) ?? 0,
            playedAt:
                playedAtRaw == null
                    ? DateTime.now()
                    : DateTime.tryParse(playedAtRaw) ?? DateTime.now(),
            playedDurationSeconds: durationByPlayer[playerId],
          );
        }).toList();

    entries.sort((a, b) {
      final durationCompare = (b.playedDurationSeconds ?? 0).compareTo(
        a.playedDurationSeconds ?? 0,
      );
      if (durationCompare != 0) return durationCompare;

      final scoreCompare = b.bestScore.compareTo(a.bestScore);
      if (scoreCompare != 0) return scoreCompare;

      return a.playedAt.compareTo(b.playedAt);
    });

    return entries;
  }

  Future<List<LeaderboardEntry>> getTop10LocalLeaderboard() async {
    final entries = await getLocalLeaderboard();
    return entries.take(10).toList();
  }
}
