import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/fly_swatter_game.dart';
import '../models/player_profile.dart';
import '../services/player_profile_service.dart';
import '../services/score_repository.dart';

/// Màn hình chơi game, chứa GameWidget và nút thoát nhanh.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final Future<_GameBootstrapData> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _loadBootstrapData();
  }

  Future<_GameBootstrapData> _loadBootstrapData() async {
    // Lay profile + ky luc truoc khi tao game instance.
    final profile = await PlayerProfileService.instance.ensureProfile();
    final bestScore = await ScoreRepository.instance.getPlayerBestScore(
      profile.playerId,
    );
    return _GameBootstrapData(profile: profile, startingBestScore: bestScore);
  }

  Future<void> _showExitDialog(
    BuildContext context,
    PlayerProfile profile,
  ) async {
    // Dialog xac nhan tranh thoat nham trong luc choi.
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.78),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'THOÁT GAME?',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFd32f2f),
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bạn có muốn quay về màn hình chính không?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF546E7A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF607D8B),
                          side: const BorderSide(color: Color(0xFFB0BEC5)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Ở lại',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFd32f2f),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Thoát',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldExit == true && context.mounted) {
      // Dong bo ten player neu co thay doi truoc khi ve menu.
      await ScoreRepository.instance.syncPlayerProfileName(profile);
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      body: FutureBuilder<_GameBootstrapData>(
        future: _bootstrapFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bootstrapData = snapshot.data!;
          final profile = bootstrapData.profile;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboardInset > 0 ? 12 : 0),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFADD8E6),
                        Color(0xFFE0F7FA),
                        Color(0xFFFFF9C4),
                        Color(0xFFFFFFE0),
                      ],
                      stops: [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    child: GameWidget(
                      game: FlySwatterGame(
                        playerProfile: profile,
                        startingBestScore: bootstrapData.startingBestScore,
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, right: 6),
                      child: IconButton(
                        onPressed: () => _showExitDialog(context, profile),
                        icon: const Icon(Icons.exit_to_app_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.94),
                          foregroundColor: const Color(0xFF37474F),
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GameBootstrapData {
  final PlayerProfile profile;
  final int startingBestScore;

  const _GameBootstrapData({
    required this.profile,
    required this.startingBestScore,
  });
}
