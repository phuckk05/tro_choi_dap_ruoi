import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/leaderboard_entry.dart';
import '../models/player_profile.dart';
import 'internet_status_service.dart';
import 'local_db_service.dart';

/// Repository trung tâm:
/// - ghi điểm vào SQLite
/// - so sánh best score local
/// - sync best score lên Firebase khi có mạng
/// - đọc top 10 cho leaderboard
class ScoreRepository {
  ScoreRepository._();

  static final ScoreRepository instance = ScoreRepository._();

  final LocalDbService _db = LocalDbService.instance;

  bool _watcherStarted = false;

  void startSyncWatcher() {
    if (_watcherStarted) return;
    _watcherStarted = true;

    InternetStatusService.instance.hasInternet.addListener(() {
      syncPendingBestScores();
    });

    syncPendingBestScores();
  }

  Future<void> recordGameResult(
    PlayerProfile profile,
    int score,
    DateTime playedAt,
  ) async {
    await _db.insertScoreEvent(profile, score, playedAt);

    final shouldSyncBestRecord = await _db.upsertPlayerBest(
      profile,
      score,
      playedAt,
    );
    if (!shouldSyncBestRecord) return;

    final pendingRecord = await _db.getPendingBestRecordByPlayerId(
      profile.playerId,
    );
    if (pendingRecord == null) return;

    if (_canSyncNow) {
      unawaited(
        _syncSingleBestScore(
          playerId: pendingRecord.playerId,
          playerName: pendingRecord.playerName,
          bestScore: pendingRecord.bestScore,
          playedAt: pendingRecord.playedAt,
        ),
      );
    }
  }

  Future<void> syncPlayerProfileName(PlayerProfile profile) async {
    final shouldSyncBestRecord = await _db.upsertPlayerBest(
      profile,
      0,
      DateTime.now(),
    );
    if (!shouldSyncBestRecord) return;

    final pendingRecord = await _db.getPendingBestRecordByPlayerId(
      profile.playerId,
    );
    if (pendingRecord == null) return;

    if (_canSyncNow) {
      unawaited(
        _syncSingleBestScore(
          playerId: pendingRecord.playerId,
          playerName: pendingRecord.playerName,
          bestScore: pendingRecord.bestScore,
          playedAt: pendingRecord.playedAt,
        ),
      );
    }
  }

  Future<void> syncPendingBestScores() async {
    if (!_canSyncNow) return;

    final pending = await _db.getPendingBestRecords();
    for (final record in pending) {
      final synced = await _pushBestScoreToFirebase(
        playerId: record.playerId,
        playerName: record.playerName,
        bestScore: record.bestScore,
        playedAt: record.playedAt,
      );
      if (synced) {
        await _db.markPlayerSynced(record.playerId);
      }
    }
  }

  Future<List<LeaderboardEntry>> getTop10Leaderboard({
    required bool preferRemote,
  }) async {
    if (preferRemote && _canUseFirebase) {
      try {
        final snapshot =
            await _firestore!
                .collection('leaderboard')
                .orderBy('bestScore', descending: true)
                .limit(10)
                .get();

        return snapshot.docs.map((doc) {
          final data = doc.data();
          final bestScore = (data['bestScore'] as num?)?.toInt() ?? 0;
          final playedAtRaw = data['playedAt'];
          final playedAt =
              playedAtRaw is Timestamp
                  ? playedAtRaw.toDate()
                  : DateTime.tryParse(playedAtRaw?.toString() ?? '') ??
                      DateTime.now();

          return LeaderboardEntry(
            playerId: data['playerId']?.toString() ?? doc.id,
            playerName: data['playerName']?.toString() ?? 'Người chơi',
            bestScore: bestScore,
            playedAt: playedAt,
          );
        }).toList();
      } catch (error) {
        debugPrint('[ScoreRepository] getTop10 remote error: $error');
        // fallback local
      }
    }

    return _db.getTop10LocalLeaderboard();
  }

  Future<bool> isPlayerNameTaken({
    required String playerName,
    required String excludingPlayerId,
  }) async {
    final normalized = playerName.trim();
    if (normalized.isEmpty) return false;

    final localTaken = await _db.isPlayerNameTaken(
      playerName: normalized,
      excludingPlayerId: excludingPlayerId,
    );
    if (localTaken) return true;

    if (!_canSyncNow) return false;

    try {
      final snapshot =
          await _firestore!
              .collection('leaderboard')
              .where('playerName', isEqualTo: normalized)
              .limit(3)
              .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final remotePlayerId = data['playerId']?.toString() ?? doc.id;
        if (remotePlayerId != excludingPlayerId) {
          return true;
        }
      }
    } catch (_) {
      // Bỏ qua lỗi mạng/cloud trong bước check để không chặn luồng chơi offline.
    }

    return false;
  }

  bool get _canUseFirebase => Firebase.apps.isNotEmpty;

  bool get _canSyncNow =>
      _canUseFirebase && InternetStatusService.instance.hasInternet.value;

  FirebaseFirestore? get _firestore =>
      _canUseFirebase ? FirebaseFirestore.instance : null;

  Future<void> _syncSingleBestScore({
    required String playerId,
    required String playerName,
    required int bestScore,
    required DateTime playedAt,
  }) async {
    final synced = await _pushBestScoreToFirebase(
      playerId: playerId,
      playerName: playerName,
      bestScore: bestScore,
      playedAt: playedAt,
    ).timeout(const Duration(seconds: 3), onTimeout: () => false);

    if (synced) {
      await _db.markPlayerSynced(playerId);
    }
  }

  Future<bool> _pushBestScoreToFirebase({
    required String playerId,
    required String playerName,
    required int bestScore,
    required DateTime playedAt,
  }) async {
    if (!_canUseFirebase) return false;

    try {
      final docRef = _firestore!.collection('leaderboard').doc(playerId);
      final current = await docRef.get();

      if (current.exists) {
        final data = current.data()!;
        final remoteBest = (data['bestScore'] as num?)?.toInt() ?? 0;
        if (remoteBest >= bestScore) {
          return true;
        }
      }

      await docRef.set({
        'playerId': playerId,
        'playerName': playerName,
        'bestScore': bestScore,
        'playedAt': Timestamp.fromDate(playedAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint(
        '[ScoreRepository] Firebase push error code=${error.code} message=${error.message}',
      );
      debugPrint('$stackTrace');
      return false;
    } catch (error, stackTrace) {
      debugPrint('[ScoreRepository] Firebase push error: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }
}
