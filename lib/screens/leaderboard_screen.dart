import 'package:flutter/material.dart';

import '../models/leaderboard_entry.dart';
import '../services/internet_status_service.dart';
import '../services/player_profile_service.dart';
import '../services/score_repository.dart';

/// Màn hình bảng xếp hạng: hiển thị top điểm trong phiên chơi hiện tại.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final Future<String> _currentPlayerIdFuture;

  Future<List<Object?>> _loadLeaderboardBundle({
    required bool hasInternet,
    required String playerId,
    required String playerName,
  }) async {
    if (hasInternet) {
      await ScoreRepository.instance.syncPendingBestScores();
    }

    return Future.wait<Object?>([
      ScoreRepository.instance.getTop10Leaderboard(preferRemote: hasInternet),
      ScoreRepository.instance.getPlayerLeaderboardRank(
        playerId: playerId,
        preferRemote: hasInternet,
        playerName: playerName,
      ),
    ]);
  }

  @override
  void initState() {
    super.initState();
    _currentPlayerIdFuture = PlayerProfileService.instance.ensureProfile().then(
      (profile) => profile.playerId,
    );
  }

  String _formatPlayedTime(DateTime dt) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(dt.day)}/${twoDigits(dt.month)} ${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
  }

  String _formatDurationCompact(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final remainSeconds = safe % 60;
    final secondText = remainSeconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}\'$secondText';
    }
    return '$minutes\'$secondText';
  }

  Color _rankAccentColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFF9A825);
      case 2:
        return const Color(0xFF78909C);
      case 3:
        return const Color(0xFF8D6E63);
      default:
        return const Color(0xFF1565C0);
    }
  }

  String _rankPrefix(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  Widget _buildLeaderboardTile({
    required LeaderboardEntry item,
    required int rank,
    required bool isMe,
  }) {
    final isTop3 = rank <= 3;
    final accentColor = _rankAccentColor(rank);
    final rankPrefix = _rankPrefix(rank);
    final playedDurationText =
        item.playedDurationSeconds != null
            ? _formatDurationCompact(item.playedDurationSeconds!)
            : '--\'--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:
            isTop3
                ? const Color(0xFFFFFBEB)
                : isMe
                ? const Color(0xFFE8F5E9)
                : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isTop3 || isMe
                  ? accentColor.withValues(alpha: 0.45)
                  : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: TextStyle(fontWeight: FontWeight.w900, color: accentColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (rankPrefix.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          rankPrefix,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        item.playerName,
                        style: TextStyle(
                          fontSize: 16,
                          color: isTop3 ? accentColor : const Color(0xFF263238),
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Bạn',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatPlayedTime(item.playedAt),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF607D8B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  playedDurationText,
                  style: TextStyle(
                    fontSize: 18,
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.bestScore}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF546E7A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _currentPlayerIdFuture,
      builder: (context, playerSnapshot) {
        if (playerSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentPlayerId = playerSnapshot.data ?? '';
        final currentPlayerName =
            PlayerProfileService.instance.currentProfile?.playerName ?? '';

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 76,
            elevation: 0,
            foregroundColor: Colors.white,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                ),
              ),
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            title: ValueListenableBuilder<bool>(
              valueListenable: InternetStatusService.instance.hasInternet,
              builder: (context, hasInternet, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Bảng xếp hạng',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasInternet
                          ? 'Đang đồng bộ dữ liệu trực tuyến'
                          : 'Đang xem dữ liệu ngoại tuyến',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE3F2FD),
                      ),
                    ),
                  ],
                );
              },
            ),
            actions: [
              IconButton(
                tooltip: 'Làm mới',
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ValueListenableBuilder<bool>(
            valueListenable: InternetStatusService.instance.hasInternet,
            builder: (context, hasInternet, _) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE3F2FD), Color(0xFFFAFAFA)],
                  ),
                ),
                child: Column(
                  children: [
                    if (!hasInternet)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFCC80)),
                        ),
                        child: const Text(
                          'Không có internet - đang hiển thị dữ liệu offline',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    Expanded(
                      child: FutureBuilder<List<Object?>>(
                        future: _loadLeaderboardBundle(
                          hasInternet: hasInternet,
                          playerId: currentPlayerId,
                          playerName: currentPlayerName,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final data = snapshot.data;
                          final leaderboard =
                              data != null && data.isNotEmpty
                                  ? (data[0] as List<LeaderboardEntry>?) ??
                                      const <LeaderboardEntry>[]
                                  : const <LeaderboardEntry>[];
                          final myRank =
                              data != null && data.length > 1
                                  ? data[1] as PlayerLeaderboardRank?
                                  : null;

                          if (leaderboard.isEmpty) {
                            return const Center(
                              child: Text(
                                'Chưa có dữ liệu\nHãy chơi một ván để lên bảng xếp hạng!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF455A64),
                                  height: 1.35,
                                ),
                              ),
                            );
                          }

                          final isMeInVisibleTopList = leaderboard.any(
                            (entry) =>
                                entry.playerId == currentPlayerId ||
                                (currentPlayerName.isNotEmpty &&
                                    entry.playerName.trim().toLowerCase() ==
                                        currentPlayerName.trim().toLowerCase()),
                          );
                          final showOutsideTop10 =
                              myRank != null && !isMeInVisibleTopList;
                          final shouldShowFirebaseMissingNotice =
                              hasInternet && myRank == null;
                          final rows = <Widget>[];

                          if (shouldShowFirebaseMissingNotice) {
                            rows.add(
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFFCC80),
                                  ),
                                ),
                                child: const Text(
                                  'Chưa có dữ liệu của bạn trên Firebase. Hãy chơi 1 ván rồi bấm Làm mới.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                              ),
                            );
                            rows.add(const SizedBox(height: 10));
                          }

                          for (
                            int index = 0;
                            index < leaderboard.length;
                            index++
                          ) {
                            final item = leaderboard[index];
                            final rank = index + 1;
                            rows.add(
                              _buildLeaderboardTile(
                                item: item,
                                rank: rank,
                                isMe: item.playerId == currentPlayerId,
                              ),
                            );
                            rows.add(const SizedBox(height: 8));
                          }

                          if (showOutsideTop10) {
                            rows.add(
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Center(
                                  child: Text(
                                    '------',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Color(0xFF90A4AE),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            );
                            rows.add(
                              _buildLeaderboardTile(
                                item: myRank.entry,
                                rank: myRank.rank,
                                isMe: true,
                              ),
                            );
                            rows.add(const SizedBox(height: 8));
                          }

                          if (rows.isNotEmpty) {
                            rows.removeLast();
                          }

                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: rows,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
