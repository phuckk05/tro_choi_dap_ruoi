/// Dữ liệu 1 dòng trong bảng xếp hạng.
class LeaderboardEntry {
  final String playerId;
  final String playerName;
  final int bestScore;
  final DateTime playedAt;

  const LeaderboardEntry({
    required this.playerId,
    required this.playerName,
    required this.bestScore,
    required this.playedAt,
  });
}
