import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/player_profile.dart';

/// Quản lý playerId duy nhất + tên người chơi ở local storage.
class PlayerProfileService {
  PlayerProfileService._();

  static final PlayerProfileService instance = PlayerProfileService._();

  static const String _playerIdKey = 'player_id';
  static const String _playerNameKey = 'player_name';

  PlayerProfile? _cached;

  PlayerProfile? get currentProfile => _cached;

  Future<PlayerProfile> ensureProfile({String? preferredName}) async {
    final prefs = await SharedPreferences.getInstance();
    var playerId = prefs.getString(_playerIdKey);
    var playerName = prefs.getString(_playerNameKey) ?? 'Người chơi';

    if (playerId == null || playerId.isEmpty) {
      playerId = const Uuid().v4();
      await prefs.setString(_playerIdKey, playerId);
    }

    final trimmed = preferredName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      playerName = trimmed;
      await prefs.setString(_playerNameKey, playerName);
    }

    _cached = PlayerProfile(playerId: playerId, playerName: playerName);
    return _cached!;
  }

  Future<void> updateName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final profile = await ensureProfile();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playerNameKey, trimmed);
    _cached = PlayerProfile(playerId: profile.playerId, playerName: trimmed);
  }
}
