import 'dart:async';
import 'dart:math';

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
    DateTime playedAt, {
    int? defeatSeconds,
    int? flyCountAtDefeat,
  }) async {
    await _db.insertScoreEvent(
      profile,
      score,
      playedAt,
      defeatSeconds: defeatSeconds,
      secendtiem: defeatSeconds,
      flyCountAtDefeat: flyCountAtDefeat,
    );

    final shouldSyncBestRecord = await _db.upsertPlayerBest(
      profile,
      score,
      playedAt,
    );

    if (!shouldSyncBestRecord) {
      if (!_canSyncNow || defeatSeconds == null) return;

      final playerBest = await _db.getPlayerBestRecordByPlayerId(
        profile.playerId,
      );
      if (playerBest == null) return;

      unawaited(
        _syncSingleBestScore(
          playerId: playerBest.playerId,
          playerName: playerBest.playerName,
          bestScore: playerBest.bestScore,
          playedAt: playerBest.playedAt,
          secendtiem: defeatSeconds,
        ),
      );
      return;
    }

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
          secendtiem: defeatSeconds,
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
    final secendtiemByPlayer = await _db.getLatestSecendtiemByPlayerIds(
      pending.map((record) => record.playerId).toList(),
    );
    for (final record in pending) {
      final synced = await _pushBestScoreToFirebase(
        playerId: record.playerId,
        playerName: record.playerName,
        bestScore: record.bestScore,
        playedAt: record.playedAt,
        secendtiem: secendtiemByPlayer[record.playerId],
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
                .orderBy('secendtiem', descending: true)
                .limit(100)
                .get();

        final byPlayerId = <String, LeaderboardEntry>{};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final bestScore = (data['bestScore'] as num?)?.toInt() ?? 0;
          final playedAtRaw = data['playedAt'];
          final playedAt =
              playedAtRaw is Timestamp
                  ? playedAtRaw.toDate()
                  : DateTime.tryParse(playedAtRaw?.toString() ?? '') ??
                      DateTime.now();

          final entry = LeaderboardEntry(
            playerId: data['playerId']?.toString() ?? doc.id,
            playerName: data['playerName']?.toString() ?? 'Người chơi',
            bestScore: bestScore,
            playedAt: playedAt,
            playedDurationSeconds:
                (data['secendtiem'] as num?)?.toInt() ??
                (data['playedDurationSeconds'] as num?)?.toInt(),
          );

          final existing = byPlayerId[entry.playerId];
          final existingDuration = existing?.playedDurationSeconds ?? 0;
          final entryDuration = entry.playedDurationSeconds ?? 0;
          if (existing == null ||
              entryDuration > existingDuration ||
              (entryDuration == existingDuration &&
                  entry.bestScore > existing.bestScore)) {
            byPlayerId[entry.playerId] = entry;
          }
        }

        final deduplicated =
            byPlayerId.values.toList()..sort((a, b) {
              final durationCompare = (b.playedDurationSeconds ?? 0).compareTo(
                a.playedDurationSeconds ?? 0,
              );
              if (durationCompare != 0) return durationCompare;

              final scoreCompare = b.bestScore.compareTo(a.bestScore);
              if (scoreCompare != 0) return scoreCompare;

              return a.playedAt.compareTo(b.playedAt);
            });
        final topList = deduplicated.take(10).toList();
        final durationByPlayer = await _db.getLatestSecendtiemByPlayerIds(
          topList.map((entry) => entry.playerId).toList(),
        );

        return topList
            .map(
              (entry) => LeaderboardEntry(
                playerId: entry.playerId,
                playerName: entry.playerName,
                bestScore: entry.bestScore,
                playedAt: entry.playedAt,
                playedDurationSeconds:
                    durationByPlayer[entry.playerId] ??
                    entry.playedDurationSeconds,
              ),
            )
            .toList();
      } catch (error) {
        debugPrint('[ScoreRepository] getTop10 remote error: $error');
        // fallback local
      }
    }

    return _db.getTop10LocalLeaderboard();
  }

  Future<int> getPlayerBestScore(String playerId) async {
    final record = await _db.getPlayerBestRecordByPlayerId(playerId);
    return record?.bestScore ?? 0;
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
    int? secendtiem,
  }) async {
    final synced = await _pushBestScoreToFirebase(
      playerId: playerId,
      playerName: playerName,
      bestScore: bestScore,
      playedAt: playedAt,
      secendtiem: secendtiem,
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
    int? secendtiem,
  }) async {
    if (!_canUseFirebase) return false;

    try {
      final leaderboard = _firestore!.collection('leaderboard');
      final docRef = leaderboard.doc(playerId);
      var current = await docRef.get();

      final localSecendtiem =
          secendtiem ??
          (await _db.getLatestSecendtiemByPlayerIds([playerId]))[playerId];

      if (!current.exists) {
        final samePlayerSnapshot =
            await leaderboard
                .where('playerId', isEqualTo: playerId)
                .limit(1)
                .get();

        if (samePlayerSnapshot.docs.isNotEmpty) {
          final legacyData = samePlayerSnapshot.docs.first.data();
          final legacyBest = (legacyData['bestScore'] as num?)?.toInt() ?? 0;
          final legacyPlayedAtRaw = legacyData['playedAt'];
          final legacyPlayedAt =
              legacyPlayedAtRaw is Timestamp
                  ? legacyPlayedAtRaw
                  : Timestamp.fromDate(DateTime.now());

          await docRef.set({
            'playerId': playerId,
            'playerName': legacyData['playerName']?.toString() ?? playerName,
            'bestScore': legacyBest,
            'playedAt': legacyPlayedAt,
            if (localSecendtiem != null) 'secendtiem': localSecendtiem,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          current = await docRef.get();
        }
      }

      if (current.exists) {
        final data = current.data()!;
        final remoteBest = (data['bestScore'] as num?)?.toInt() ?? 0;
        final remoteName = data['playerName']?.toString().trim() ?? '';
        final remoteSecendtiem = (data['secendtiem'] as num?)?.toInt() ?? 0;
        final localDuration = localSecendtiem ?? 0;
        final shouldPromoteDuration = localDuration > remoteSecendtiem;
        final shouldPromoteScore = bestScore > remoteBest;
        final shouldUpdateName = remoteName != playerName.trim();

        if (!shouldPromoteDuration &&
            !shouldPromoteScore &&
            !shouldUpdateName) {
          return true;
        }

        final remotePlayedAtRaw = data['playedAt'];
        final remotePlayedAt =
            remotePlayedAtRaw is Timestamp
                ? remotePlayedAtRaw
                : Timestamp.fromDate(DateTime.now());

        await docRef.set({
          'playerId': playerId,
          'playerName': playerName,
          'bestScore': shouldPromoteScore ? bestScore : remoteBest,
          'playedAt':
              shouldPromoteDuration
                  ? Timestamp.fromDate(playedAt)
                  : remotePlayedAt,
          'secendtiem': max(remoteSecendtiem, localDuration),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }

      await docRef.set({
        'playerId': playerId,
        'playerName': playerName,
        'bestScore': bestScore,
        'playedAt': Timestamp.fromDate(playedAt),
        'secendtiem': localSecendtiem ?? 0,
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
