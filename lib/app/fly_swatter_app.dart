import 'package:flutter/material.dart';

import '../screens/game_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/main_menu_screen.dart';
import '../services/internet_status_service.dart';
import '../services/player_profile_service.dart';
import '../services/score_repository.dart';

/// Root app: tập trung cấu hình route để các màn hình dễ tách rời và bảo trì.
class FlySwatterApp extends StatefulWidget {
  const FlySwatterApp({super.key});

  @override
  State<FlySwatterApp> createState() => _FlySwatterAppState();
}

class _FlySwatterAppState extends State<FlySwatterApp> {
  @override
  void initState() {
    super.initState();
    InternetStatusService.instance.start();
    ScoreRepository.instance.startSyncWatcher();
    PlayerProfileService.instance.ensureProfile();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const MainMenuScreen(),
        '/game': (context) => const GameScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
      },
    );
  }
}
