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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bảng xếp hạng'),
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
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
                      child: FutureBuilder<List<LeaderboardEntry>>(
                        future: ScoreRepository.instance.getTop10Leaderboard(
                          preferRemote: hasInternet,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final leaderboard = snapshot.data ?? [];
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

                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: leaderboard.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = leaderboard[index];
                              final rank = index + 1;
                              final isTop3 = rank <= 3;
                              final isMe = item.playerId == currentPlayerId;
                              final accentColor = _rankAccentColor(rank);
                              final rankPrefix = _rankPrefix(rank);

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
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
                                            ? accentColor.withValues(
                                              alpha: 0.45,
                                            )
                                            : Colors.transparent,
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
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
                                        color: accentColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$rank',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: accentColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (rankPrefix.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 6,
                                                      ),
                                                  child: Text(
                                                    rankPrefix,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                              Expanded(
                                                child: Text(
                                                  item.playerName,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color:
                                                        isTop3
                                                            ? accentColor
                                                            : const Color(
                                                              0xFF263238,
                                                            ),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isMe)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    left: 8,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF2E7D32,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Bạn',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                    Text(
                                      '${item.bestScore}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        color:
                                            isTop3
                                                ? accentColor
                                                : const Color(0xFF2E7D32),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
