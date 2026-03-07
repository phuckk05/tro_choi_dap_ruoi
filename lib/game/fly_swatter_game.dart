import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        HapticFeedback,
        MissingPluginException,
        SystemSound,
        SystemSoundType,
        rootBundle;

import '../models/player_profile.dart';
import '../screens/game_over_screen.dart';
import '../services/score_repository.dart';

part 'components/background_components.part.dart';
part 'components/fly_component.part.dart';
part 'components/hud_components.part.dart';
part 'components/tool_components.part.dart';
part 'components/world_components.part.dart';
part 'models/gameplay_types.part.dart';

/// Core game loop và toàn bộ component gameplay.
class FlySwatterGame extends FlameGame
    with HasCollisionDetection, TapCallbacks {
  final PlayerProfile playerProfile;
  final int startingBestScore;
  final List<AudioPlayer> _activeSfxPlayers = <AudioPlayer>[];
  final Map<ToolType, List<AudioPlayer>> _toolSfxPools =
      <ToolType, List<AudioPlayer>>{};
  final Map<ToolType, int> _toolSfxPoolCursor = <ToolType, int>{};
  final List<AudioPlayer> _flyTapSfxPool = <AudioPlayer>[];
  int _flyTapSfxCursor = 0;
  int _lastFlyTapSfxMs = 0;
  AudioPlayer? _slapLoopPlayer;

  int score = 0;
  late int highScore;
  int combo = 0;
  double normalSpawnTimer = 0;
  double elapsedTime = 0;
  bool _gameplayStarted = false;
  bool _initialWaveSpawned = false;
  double _startCountdownRemaining = 3;
  int _lastCountdownShown = -1;
  final Random random = Random();
  bool gameOver = false;
  bool _initialized = false;
  int _lastShownSecond = -1;
  double _comboResetRemaining = 0;
  double _swatBurstWindow = 0;
  int _swatBurstCount = 0;
  bool _endingTriggered = false;
  int _noodleDropHits = 0;
  bool _defeatStatsCaptured = false;
  int _defeatSeconds = 0;
  int _defeatFlyCount = 0;
  final List<_PendingCollisionSpawn> _pendingCollisionSpawns = [];
  final Set<int> _lockedFlyIds = <int>{};
  int _edgeSpawnCursor = 0;
  int _difficultyLevel = 0;
  double _bossSpawnTimer = 0;
  int _bowlShieldHitPoints = 0;
  double _slapToolRemaining = 0;
  double _slapToolMaxDuration = 5;
  static const double _toolBarBaseY = 68;
  static const int _shieldMaxHitPoints = 10;
  static const double _lightningSfxVolume = 0.9;
  static const double _slapSfxVolume = 0.92;
  static const double _shieldSfxVolume = 0.9;
  static const double _flyTapSfxVolume = 0.86;
  static const int _toolSfxPoolSize = 8;
  static const int _flyTapSfxPoolSize = 10;
  static const int _flyTapSfxMinGapMs = 35;
  static const String _strikeSfxAsset = 'assets/sounds/tiaset.wav';
  static const String _slapSfxAsset = 'assets/sounds/chichruoi.wav';
  static const String _shieldSfxAsset = 'assets/sounds/daynap.wav';
  static const String _flyTapSfxAsset = 'assets/sounds/dapruoi.wav';
  static final AudioContext _sfxAudioContext =
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
  bool _bossWaveActive = false;
  int _bossAbsorbedFlyTotal = 0;
  int _normalFlyDefeatCounter = 0;
  SwatNetOverlay? _swatNetOverlay;
  final Map<ToolType, int> _toolInventory = {
    ToolType.shield: 0,
    ToolType.slap: 0,
    ToolType.strikeSet: 0,
  };
  final List<Color> _mutantColors = const [
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFFEF6C00),
    Color(0xFF3949AB),
  ];

  static const int _maxChildFlies = 100;
  static const int _maxTotalFlies = 240;
  static const int _maxNoodleDrops = 100;
  static const int _maxDifficultyLevel = 99;
  static const int _difficultyStepSeconds = 60;
  static final List<String> _difficultyNames = <String>[
    'Sơ cấp',
    'Trung cấp',
    'Cao cấp',
    ...List<String>.generate(16, (index) => 'Khát máu ${index + 1}'),
    ...List<String>.generate(16, (index) => 'Hung thần ${index + 1}'),
    ...List<String>.generate(16, (index) => 'Hủy diệt ${index + 1}'),
    ...List<String>.generate(16, (index) => 'Địa ngục ${index + 1}'),
    ...List<String>.generate(16, (index) => 'Tuyệt diệt ${index + 1}'),
    ...List<String>.generate(16, (index) => 'Tận thế ${index + 1}'),
  ];

  // So luong ruoi con dang ton tai (ruoi dot bien tu sinh san).
  int get _activeChildFlyCount =>
      children
          .whereType<Fly>()
          .where((fly) => fly.isMutant && !fly.isSwatted)
          .length;

  double get _currentSpeedMultiplier =>
      _speedMultiplierForLevel(_difficultyLevel);

  bool get _hasAliveBosses => children.whereType<Fly>().any(
    (fly) => fly.isBoss && !fly.isSwatted && fly.parent != null,
  );

  int get _bossExponent => _difficultyLevel + 1;

  // Cong thuc user yeu cau: HP boss = 2^n + 2 theo cap.
  int get _bossHealthForLevel => (1 << _bossExponent) + 2;

  // Cong thuc user yeu cau: sat thuong boss = 2^n theo cap.
  int get _bossDamageForLevel => 1 << _bossExponent;

  late ScoreCard scoreCard;
  late SlapEnergyBar slapEnergyBar;
  late NoodleBowl noodleBowl;
  ToolRack? toolRack;
  DifficultyNotice? difficultyNotice;

  FlySwatterGame({
    required this.playerProfile,
    required this.startingBestScore,
  }) {
    highScore = startingBestScore;
  }

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // HUD diem/thoi gian.
    scoreCard = ScoreCard(position: Vector2(10, 10), game: this);
    add(scoreCard);

    slapEnergyBar = SlapEnergyBar(position: Vector2(10, 68));
    add(slapEnergyBar);
    slapEnergyBar.setSlap(remaining: 0, maxDuration: _slapToolMaxDuration);

    // Banner thong bao cap do kho.
    difficultyNotice = DifficultyNotice();
    add(difficultyNotice!);
    _updateDifficultyNoticePosition();

    toolRack = ToolRack(onToolTap: _onToolTap);
    add(toolRack!);
    _updateToolRackPosition();
    _syncToolRackCounts();

    await _initToolSfxPools();
    await _initFlyTapSfxPool();

    _ensureInitialized();
  }

  @override
  void onRemove() {
    for (final player in _activeSfxPlayers) {
      player.dispose();
    }
    _activeSfxPlayers.clear();

    for (final pool in _toolSfxPools.values) {
      for (final player in pool) {
        player.dispose();
      }
    }
    _toolSfxPools.clear();
    _toolSfxPoolCursor.clear();
    for (final player in _flyTapSfxPool) {
      player.dispose();
    }
    _flyTapSfxPool.clear();
    _flyTapSfxCursor = 0;
    _stopSlapLoopSfx();
    super.onRemove();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _ensureInitialized();
    if (difficultyNotice?.parent != null) {
      _updateDifficultyNoticePosition();
    }
    if (_initialized && noodleBowl.parent != null) {
      _updateNoodleBowlPosition();
    }
    if (toolRack?.parent != null) {
      _updateToolRackPosition();
    }
    _swatNetOverlay?.setScreenSize(size);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _playFlyHitSfx();
  }

  void _ensureInitialized() {
    // Dam bao map chi duoc tao mot lan khi kich thuoc game da san sang.
    if (_initialized || size.x <= 0 || size.y <= 0) return;
    _initialized = true;
    _addBackgroundElements();
    _showStartCountdown();
  }

  void _addBackgroundElements() {
    // Cac thanh phan background/foreground tinh cho map.
    add(Sun(position: Vector2(size.x - 100, 100)));

    for (int i = 0; i < 6; i++) {
      add(
        Cloud(
          position: Vector2(
            random.nextDouble() * size.x,
            50 + random.nextDouble() * 200,
          ),
        ),
      );
    }

    add(Grass(position: Vector2(0, size.y - 100)));

    for (int i = 0; i < 10; i++) {
      add(Bush(position: Vector2(random.nextDouble() * size.x, size.y - 80)));
    }

    noodleBowl = NoodleBowl(position: Vector2.zero());
    add(noodleBowl);
    _updateNoodleBowlPosition();
    noodleBowl.setContaminationProgress(100);
  }

  void _updateNoodleBowlPosition() {
    noodleBowl.position = Vector2(
      (size.x - noodleBowl.size.x) / 2,
      size.y - noodleBowl.size.y - 10,
    );
  }

  void _updateDifficultyNoticePosition() {
    final notice = difficultyNotice;
    if (notice == null) return;
    final panelWidth = max(220.0, min(360.0, size.x - 24));
    notice.setPanelWidth(panelWidth);
    notice.position = Vector2(size.x / 2, size.y / 2);
  }

  void _updateToolRackPosition() {
    final rack = toolRack;
    if (rack == null) return;
    rack.position = Vector2(size.x - 2, size.y - 2);
  }

  void _syncToolRackCounts() {
    final rack = toolRack;
    if (rack == null) return;
    rack.setCount(ToolType.shield, _toolInventory[ToolType.shield] ?? 0);
    rack.setCount(ToolType.slap, _toolInventory[ToolType.slap] ?? 0);
    rack.setCount(ToolType.strikeSet, _toolInventory[ToolType.strikeSet] ?? 0);
  }

  void _addTool(ToolType type, {int amount = 1}) {
    _toolInventory[type] = (_toolInventory[type] ?? 0) + amount;
    _syncToolRackCounts();
  }

  bool _consumeTool(ToolType type, {int amount = 1}) {
    final current = _toolInventory[type] ?? 0;
    if (current < amount) return false;
    _toolInventory[type] = current - amount;
    _syncToolRackCounts();
    return true;
  }

  ToolType _randomToolType() {
    final values = ToolType.values;
    return values[random.nextInt(values.length)];
  }

  void _rewardToolsWithAnimation(
    Vector2 fromPosition, {
    required int count,
    double minDelay = 1.0,
    double maxDelay = 2.0,
  }) {
    for (int i = 0; i < count; i++) {
      final type = _randomToolType();
      final delay = minDelay + random.nextDouble() * (maxDelay - minDelay);
      final offset = Vector2(
        (random.nextDouble() - 0.5) * 26,
        (random.nextDouble() - 0.5) * 20,
      );
      add(
        ToolPickupFlyToRack(
          type: type,
          startPosition: fromPosition.clone() + offset,
          targetPositionProvider:
              () => toolRack?.getSlotWorldCenter(type) ?? fromPosition.clone(),
          holdDuration: delay,
          onArrive: () => _addTool(type),
        ),
      );
    }
  }

  void _onToolTap(ToolType type) {
    if (gameOver || !_gameplayStarted) return;

    switch (type) {
      case ToolType.shield:
        _useShieldTool();
        break;
      case ToolType.slap:
        _useSlapTool();
        break;
      case ToolType.strikeSet:
        _useStrikeSetTool();
        break;
    }
  }

  void _useShieldTool() {
    if (!_consumeTool(ToolType.shield)) {
      return;
    }
    _playShieldSfx();
    _activateBowlShield(hits: _shieldMaxHitPoints);
  }

  void _useSlapTool() {
    if (_swatNetOverlay?.parent != null) {
      return;
    }

    if (!_consumeTool(ToolType.slap)) {
      return;
    }

    _playSlapSfx();
    _startSlapLoopSfx();

    _slapToolRemaining = 5;
    _slapToolMaxDuration = 5;
    slapEnergyBar.setSlap(
      remaining: _slapToolRemaining,
      maxDuration: _slapToolMaxDuration,
    );

    _swatNetOverlay = SwatNetOverlay(
      screenSize: size.clone(),
      onSwatAt: (worldPoint) {
        _swatFliesInRadius(worldPoint, radius: 58);
      },
      onFinished: () {
        _slapToolRemaining = 0;
        slapEnergyBar.setSlap(remaining: 0, maxDuration: _slapToolMaxDuration);
        _stopSlapLoopSfx();
        _swatNetOverlay = null;
      },
      duration: _slapToolMaxDuration,
    );
    add(_swatNetOverlay!);
  }

  void _useStrikeSetTool() {
    if (!_consumeTool(ToolType.strikeSet)) {
      return;
    }

    _playLightningSfx();

    final aliveFlies =
        children.whereType<Fly>().where((fly) => !fly.isSwatted).toList();
    if (aliveFlies.isEmpty) {
      return;
    }

    final strikeTargets = <Vector2>[];
    for (int i = 0; i < 3; i++) {
      final fly = aliveFlies[i % aliveFlies.length];
      strikeTargets.add(fly.position.clone());
    }

    add(
      LightningStormEffect(
        screenSize: size.clone(),
        strikeTargets: strikeTargets,
        onCompleted: () {
          _zapAllCurrentFlies();
        },
      ),
    );
  }

  Future<void> _playLightningSfx() async {
    _markToolSfxPriority();
    await _playToolSfxStableOneShot(
      assetPath: _strikeSfxAsset,
      volume: _lightningSfxVolume,
      fallbackTone: SystemSoundType.alert,
      heavyHaptic: true,
    );
  }

  Future<void> _playSlapSfx() async {
    _markToolSfxPriority();
    await _playToolSfxFromPool(
      type: ToolType.slap,
      assetPath: _slapSfxAsset,
      volume: _slapSfxVolume,
      fallbackTone: SystemSoundType.click,
      heavyHaptic: false,
    );
  }

  Future<void> _playShieldSfx() async {
    _markToolSfxPriority();
    await _playToolSfxStableOneShot(
      assetPath: _shieldSfxAsset,
      volume: _shieldSfxVolume,
      fallbackTone: SystemSoundType.click,
      heavyHaptic: false,
    );
  }

  Future<void> _playToolSfxStableOneShot({
    required String assetPath,
    required double volume,
    required SystemSoundType fallbackTone,
    required bool heavyHaptic,
  }) async {
    final mediaPlayerOk = await _playAssetSfx(
      assetPath: assetPath,
      volume: volume,
      fallbackTone: fallbackTone,
      heavyHaptic: heavyHaptic,
      playerMode: PlayerMode.mediaPlayer,
    );
    if (mediaPlayerOk) return;

    await _playAssetSfx(
      assetPath: assetPath,
      volume: volume,
      fallbackTone: fallbackTone,
      heavyHaptic: heavyHaptic,
      playerMode: PlayerMode.lowLatency,
    );
  }

  Future<void> _initToolSfxPools() async {
    if (_toolSfxPools.isNotEmpty) return;

    for (final type in ToolType.values) {
      final players = <AudioPlayer>[];
      for (int i = 0; i < _toolSfxPoolSize; i++) {
        final player = AudioPlayer();
        try {
          await _configureSfxPlayer(player, playerMode: PlayerMode.lowLatency);
          players.add(player);
        } catch (_) {
          player.dispose();
        }
      }
      _toolSfxPools[type] = players;
      _toolSfxPoolCursor[type] = 0;
    }
  }

  Future<void> _playToolSfxFromPool({
    required ToolType type,
    required String assetPath,
    required double volume,
    required SystemSoundType fallbackTone,
    required bool heavyHaptic,
  }) async {
    final pool = _toolSfxPools[type] ?? const <AudioPlayer>[];
    if (pool.isEmpty) {
      await _playToolSfxReliable(
        assetPath: assetPath,
        volume: volume,
        fallbackTone: fallbackTone,
        heavyHaptic: heavyHaptic,
      );
      return;
    }

    final cursor = _toolSfxPoolCursor[type] ?? 0;
    final slotIndex = cursor % pool.length;
    final player = pool[slotIndex];
    _toolSfxPoolCursor[type] = (cursor + 1) % pool.length;

    try {
      await player.setReleaseMode(ReleaseMode.stop);
      try {
        await player.stop();
      } catch (_) {}
      await player.setVolume(volume);
      await player.play(AssetSource(_assetSourcePath(assetPath)));

      if (heavyHaptic) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {
      await _rebuildPoolPlayer(type: type, slotIndex: slotIndex);
      await _playToolSfxReliable(
        assetPath: assetPath,
        volume: volume,
        fallbackTone: fallbackTone,
        heavyHaptic: heavyHaptic,
      );
    }
  }

  Future<void> _rebuildPoolPlayer({
    required ToolType type,
    required int slotIndex,
  }) async {
    final pool = _toolSfxPools[type];
    if (pool == null || slotIndex < 0 || slotIndex >= pool.length) return;

    final oldPlayer = pool[slotIndex];
    try {
      await oldPlayer.stop();
    } catch (_) {}
    oldPlayer.dispose();

    final replacement = AudioPlayer();
    try {
      await _configureSfxPlayer(replacement, playerMode: PlayerMode.lowLatency);
      pool[slotIndex] = replacement;
    } catch (_) {
      replacement.dispose();
      final fallback = AudioPlayer();
      await _configureSfxPlayer(fallback, playerMode: PlayerMode.mediaPlayer);
      pool[slotIndex] = fallback;
    }
  }

  Future<void> _startSlapLoopSfx() async {
    try {
      await _stopSlapLoopSfx();
      final player = AudioPlayer();
      _slapLoopPlayer = player;
      await _configureSfxPlayer(player, playerMode: PlayerMode.mediaPlayer);
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume((_slapSfxVolume * 0.72).clamp(0, 1));
      await player.play(AssetSource(_assetSourcePath(_slapSfxAsset)));
    } catch (_) {
      // Neu loop khong ho tro tren thiet bi, bo qua de tranh anh huong gameplay.
    }
  }

  Future<void> _stopSlapLoopSfx() async {
    final player = _slapLoopPlayer;
    _slapLoopPlayer = null;
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {}
    player.dispose();
  }

  Future<void> _playToolSfxReliable({
    required String assetPath,
    required double volume,
    required SystemSoundType fallbackTone,
    required bool heavyHaptic,
  }) async {
    final lowLatencyOk = await _playAssetSfx(
      assetPath: assetPath,
      volume: volume,
      fallbackTone: fallbackTone,
      heavyHaptic: heavyHaptic,
      playerMode: PlayerMode.lowLatency,
    );
    if (lowLatencyOk) return;

    await _playAssetSfx(
      assetPath: assetPath,
      volume: volume,
      fallbackTone: fallbackTone,
      heavyHaptic: heavyHaptic,
      playerMode: PlayerMode.mediaPlayer,
    );
  }

  Future<void> _configureSfxPlayer(
    AudioPlayer player, {
    required PlayerMode playerMode,
  }) async {
    await player.setAudioContext(_sfxAudioContext);
    await player.setPlayerMode(playerMode);
  }

  void _markToolSfxPriority() {
    // Giu hook de de mo rong uu tien am thanh tool khi can.
  }

  Future<void> _initFlyTapSfxPool() async {
    if (_flyTapSfxPool.isNotEmpty) return;

    for (int i = 0; i < _flyTapSfxPoolSize; i++) {
      final player = AudioPlayer();
      try {
        await _configureSfxPlayer(player, playerMode: PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        _flyTapSfxPool.add(player);
      } catch (_) {
        player.dispose();
      }
    }
  }

  Future<void> _playFlyHitSfx() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastFlyTapSfxMs < _flyTapSfxMinGapMs) {
      return;
    }
    _lastFlyTapSfxMs = nowMs;

    if (_flyTapSfxPool.isEmpty) {
      await _playAssetSfx(
        assetPath: _flyTapSfxAsset,
        volume: _flyTapSfxVolume,
        fallbackTone: SystemSoundType.click,
        heavyHaptic: false,
        playerMode: PlayerMode.mediaPlayer,
      );
      return;
    }

    final slot = _flyTapSfxCursor % _flyTapSfxPool.length;
    _flyTapSfxCursor = (_flyTapSfxCursor + 1) % _flyTapSfxPool.length;
    final player = _flyTapSfxPool[slot];
    try {
      try {
        await player.stop();
      } catch (_) {}
      await player.setVolume(_flyTapSfxVolume);
      await player.play(AssetSource(_assetSourcePath(_flyTapSfxAsset)));
    } catch (_) {
      await _rebuildFlyTapSfxPlayer(slot);
      await _playAssetSfx(
        assetPath: _flyTapSfxAsset,
        volume: _flyTapSfxVolume,
        fallbackTone: SystemSoundType.click,
        heavyHaptic: false,
        playerMode: PlayerMode.mediaPlayer,
      );
    }
  }

  Future<void> _rebuildFlyTapSfxPlayer(int slot) async {
    if (slot < 0 || slot >= _flyTapSfxPool.length) return;
    final old = _flyTapSfxPool[slot];
    try {
      await old.stop();
    } catch (_) {}
    old.dispose();

    final replacement = AudioPlayer();
    try {
      await _configureSfxPlayer(replacement, playerMode: PlayerMode.lowLatency);
      await replacement.setReleaseMode(ReleaseMode.stop);
      _flyTapSfxPool[slot] = replacement;
    } catch (_) {
      replacement.dispose();
      final fallback = AudioPlayer();
      await _configureSfxPlayer(fallback, playerMode: PlayerMode.mediaPlayer);
      await fallback.setReleaseMode(ReleaseMode.stop);
      _flyTapSfxPool[slot] = fallback;
    }
  }

  Future<bool> _playAssetSfx({
    required String assetPath,
    List<String> fallbackAssetPaths = const [],
    required double volume,
    required SystemSoundType fallbackTone,
    required bool heavyHaptic,
    PlayerMode playerMode = PlayerMode.mediaPlayer,
  }) async {
    try {
      final candidates = <String>[assetPath, ...fallbackAssetPaths];

      if (candidates.isEmpty) {
        await SystemSound.play(fallbackTone);
        return false;
      }

      AudioPlayer? playingPlayer;
      for (final candidate in candidates) {
        final player = AudioPlayer();
        try {
          await _configureSfxPlayer(player, playerMode: playerMode);
          await player.setVolume(volume);
          await player.play(AssetSource(_assetSourcePath(candidate)));
          playingPlayer = player;
          _activeSfxPlayers.add(player);
          break;
        } catch (_) {
          player.dispose();
        }
      }

      if (playingPlayer == null) {
        await SystemSound.play(fallbackTone);
        return false;
      }

      final selectedPlayer = playingPlayer;
      selectedPlayer.onPlayerComplete.first.then((_) {
        _activeSfxPlayers.remove(selectedPlayer);
        selectedPlayer.dispose();
      });

      if (heavyHaptic) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      return true;
    } on MissingPluginException {
      // Fallback de van co phan hoi am thanh neu plugin audio chua dang ky.
      await SystemSound.play(fallbackTone);
      if (heavyHaptic) {
        HapticFeedback.heavyImpact();
      }
      return false;
    } catch (_) {
      // Bo qua loi am thanh de tranh anh huong gameplay.
      return false;
    }
  }

  String _assetSourcePath(String assetPath) {
    return assetPath.replaceFirst('assets/', '');
  }

  void _swatFliesInRadius(Vector2 worldPoint, {required double radius}) {
    final aliveFlies =
        children.whereType<Fly>().where((fly) => !fly.isSwatted).toList();
    final r2 = radius * radius;
    for (final fly in aliveFlies) {
      if (fly.position.distanceToSquared(worldPoint) <= r2) {
        if (fly.isBoss) {
          fly.applyDamage(amount: 1, playHitSfx: false);
        } else {
          fly.forceSwat(playHitSfx: false);
        }
      }
    }
  }

  void _zapAllCurrentFlies() {
    final aliveFlies =
        children.whereType<Fly>().where((fly) => !fly.isSwatted).toList();
    for (final fly in aliveFlies) {
      if (fly.isBoss) {
        fly.applyDamage(amount: 2, playHitSfx: false);
      } else {
        fly.forceSwat(playHitSfx: false);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    _ensureInitialized();

    if (gameOver) return;

    if (!_gameplayStarted) {
      _updateStartCountdown(dt);
      return;
    }

    _updatePerformanceBudget(dt);

    elapsedTime += dt;

    final currentSecond = elapsedTime.floor();
    if (currentSecond != _lastShownSecond) {
      _lastShownSecond = currentSecond;
      scoreCard.updateTime(currentSecond);
      _updateDifficultyByTime(currentSecond);
    }

    _updatePendingCollisionSpawns(dt);
    _handleFlyCollisionSpawn();
    _updateShield();
    _updateSlapTool(dt);
    _updateToolBarsLayout(dt);
    if (_bossWaveActive) {
      _routeNonBossFliesToBoss();
    }

    if (_bossWaveActive && !_hasAliveBosses) {
      _bossWaveActive = false;
      difficultyNotice?.show('Đợt boss kết thúc');
    }

    // Spawn ruoi theo cap do kho hien tai.
    final spawnInterval = _spawnIntervalForLevel(_difficultyLevel);
    final spawnCount = _spawnCountForLevel(_difficultyLevel);

    if (!_bossWaveActive) {
      normalSpawnTimer += dt;
      while (normalSpawnTimer >= spawnInterval) {
        normalSpawnTimer -= spawnInterval;
        _spawnNormalFliesFromEdges(count: spawnCount);
      }
    }

    if (!_bossWaveActive) {
      _bossSpawnTimer += dt;
      final bossSpawnInterval = _bossSpawnIntervalForLevel(_difficultyLevel);
      if (_bossSpawnTimer >= bossSpawnInterval) {
        _bossSpawnTimer = 0;
        _startBossWave();
      }
    }
  }

  void _showStartCountdown() {
    _startCountdownRemaining = 3;
    _lastCountdownShown = -1;
    _gameplayStarted = false;
    difficultyNotice?.show('3', duration: 0.95);
  }

  void _updateStartCountdown(double dt) {
    if (_gameplayStarted) return;

    _startCountdownRemaining = max(0, _startCountdownRemaining - dt);
    final tick = _startCountdownRemaining.ceil();
    if (tick > 0 && tick != _lastCountdownShown) {
      _lastCountdownShown = tick;
      difficultyNotice?.show('$tick', duration: 0.95);
    }

    if (_startCountdownRemaining <= 0) {
      _gameplayStarted = true;
      difficultyNotice?.show('Bắt đầu!', duration: 0.7);
      if (!_initialWaveSpawned) {
        _spawnInitialEdgeWave();
        _initialWaveSpawned = true;
      }
    }
  }

  void _updatePerformanceBudget(double dt) {
    if (_swatBurstWindow > 0) {
      _swatBurstWindow = max(0, _swatBurstWindow - dt);
      if (_swatBurstWindow <= 0) {
        _swatBurstCount = 0;
      }
    }

    if (combo > 0 && _comboResetRemaining > 0) {
      _comboResetRemaining = max(0, _comboResetRemaining - dt);
      if (_comboResetRemaining <= 0) {
        combo = 0;
        scoreCard.updateScore(score, 0, highScore);
      }
    }
  }

  void _registerSwatBurst() {
    if (_swatBurstWindow <= 0) {
      _swatBurstWindow = 0.55;
      _swatBurstCount = 1;
      return;
    }
    _swatBurstCount++;
    _swatBurstWindow = 0.55;
  }

  int _effectLoadLevel() {
    if (_swatBurstCount >= 14) return 2;
    if (_swatBurstCount >= 7) return 1;
    return 0;
  }

  void _updateShield() {
    noodleBowl.setShieldState(
      active: _bowlShieldHitPoints > 0,
      currentHits: _bowlShieldHitPoints,
      maxHits: _shieldMaxHitPoints,
    );
  }

  void _updateSlapTool(double dt) {
    if (_slapToolRemaining <= 0) {
      slapEnergyBar.setSlap(remaining: 0, maxDuration: _slapToolMaxDuration);
      _stopSlapLoopSfx();
      return;
    }

    _slapToolRemaining = max(0, _slapToolRemaining - dt);
    slapEnergyBar.setSlap(
      remaining: _slapToolRemaining,
      maxDuration: _slapToolMaxDuration,
    );
  }

  void _updateToolBarsLayout(double dt) {
    final slapVisible = _slapToolRemaining > 0;
    final slapTargetY = _toolBarBaseY;
    final smoothing = min(1.0, dt * 12);

    slapEnergyBar.position.y +=
        (slapTargetY - slapEnergyBar.position.y) * smoothing;

    if (slapVisible) {
      slapEnergyBar.priority = 3;
    } else {
      slapEnergyBar.priority = 2;
    }
  }

  int _resolveDifficultyLevel(int seconds) {
    return (seconds ~/ _difficultyStepSeconds).clamp(0, _maxDifficultyLevel);
  }

  void _updateDifficultyByTime(int seconds) {
    final nextLevel = _resolveDifficultyLevel(seconds);
    if (nextLevel == _difficultyLevel) return;

    _difficultyLevel = nextLevel;
    final tierName = _difficultyNameForLevel(nextLevel);
    final message = 'Cấp ${nextLevel + 1} - $tierName';
    difficultyNotice?.show(message);
    add(ScreenFlashEffect(screenSize: size.clone()));
  }

  String _difficultyNameForLevel(int level) {
    if (_difficultyNames.isEmpty) {
      return 'Bac ${level + 1}';
    }
    return _difficultyNames[min(level, _difficultyNames.length - 1)];
  }

  void _spawnInitialEdgeWave() {
    _spawnNormalFliesFromEdges(count: _spawnCountForLevel(0));
  }

  int _spawnCountForLevel(int level) {
    return (2 + (level ~/ 2)).clamp(2, 26);
  }

  double _spawnIntervalForLevel(int level) {
    return max(0.28, 2.2 - (level * 0.02));
  }

  double _speedMultiplierForLevel(int level) {
    return min(2.4, 0.95 + (level * 0.015));
  }

  double _bossSpawnIntervalForLevel(int level) {
    return 50;
  }

  int _bossCountForLevel(int level) {
    return (1 + (level ~/ 30)).clamp(1, 4);
  }

  void _spawnNormalFliesFromEdges({required int count}) {
    for (int index = 0; index < count; index++) {
      final edge = _Edge.values[_edgeSpawnCursor % _Edge.values.length];
      _edgeSpawnCursor++;
      _spawnEdgeFly(edge);
    }
  }

  void _startBossWave() {
    if (_bossWaveActive) return;
    _bossWaveActive = true;

    final bossCount = _bossCountForLevel(_difficultyLevel);
    for (int i = 0; i < bossCount; i++) {
      _spawnBossFlyFromEdge();
    }
    _routeNonBossFliesToBoss();
    difficultyNotice?.show(
      'Boss x$bossCount • HP $_bossHealthForLevel • DMG $_bossDamageForLevel',
    );
  }

  void _routeNonBossFliesToBoss() {
    final aliveBosses = children
        .whereType<Fly>()
        .where((fly) => fly.isBoss && !fly.isSwatted && fly.parent != null)
        .toList(growable: false);
    if (aliveBosses.isEmpty) return;

    final nonBossFlies = children
        .whereType<Fly>()
        .where((fly) => !fly.isBoss && !fly.isSwatted && fly.parent != null)
        .toList(growable: false);

    for (final fly in nonBossFlies) {
      final targetBoss = _nearestBossFor(fly.position, aliveBosses);
      if (targetBoss == null) continue;
      fly.startAbsorbIntoBoss(targetBoss);
    }
  }

  Fly? _nearestBossFor(Vector2 position, List<Fly> bosses) {
    Fly? best;
    var bestDist = double.infinity;
    for (final boss in bosses) {
      final d2 = boss.position.distanceToSquared(position);
      if (d2 < bestDist) {
        bestDist = d2;
        best = boss;
      }
    }
    return best;
  }

  void onFlyMergedIntoBoss({required Fly boss, required Fly absorbedFly}) {
    if (gameOver || boss.isSwatted || !boss.isBoss) return;

    final healthGain = absorbedFly.isMutant ? 2 : 1;
    final damageGain = absorbedFly.isMutant ? 2 : 1;
    _bossAbsorbedFlyTotal++;
    boss.absorbFlyPower(healthGain: healthGain, damageGain: damageGain);

    add(
      FloatingRewardText(
        position: boss.position.clone() + Vector2(0, -26),
        text: '+$healthGain HP  +$damageGain DMG',
        color: const Color(0xFFE53935),
        lifetime: 0.52,
        riseSpeed: 24,
      ),
    );

    if (_bossAbsorbedFlyTotal % 8 == 0) {
      difficultyNotice?.show(
        'Boss đang tiến hóa: +$_bossAbsorbedFlyTotal hấp thụ',
      );
    }
  }

  void _spawnBossFlyFromEdge() {
    final activeBosses =
        children
            .whereType<Fly>()
            .where((fly) => fly.isBoss && !fly.isSwatted)
            .length;
    final maxBoss = _bossCountForLevel(_difficultyLevel);
    if (activeBosses >= maxBoss) return;

    final edge = _Edge.values[_edgeSpawnCursor % _Edge.values.length];
    _edgeSpawnCursor++;
    _spawnEdgeFly(edge, isBoss: true);
  }

  void _spawnEdgeFly(_Edge edge, {bool isBoss = false}) {
    final flyCount = children.whereType<Fly>().length;
    if (flyCount >= _maxTotalFlies) return;

    late final Vector2 startPosition;
    switch (edge) {
      case _Edge.top:
        startPosition = Vector2(40 + random.nextDouble() * (size.x - 80), -40);
        break;
      case _Edge.right:
        startPosition = Vector2(
          size.x + 40,
          160 + random.nextDouble() * (size.y - 330),
        );
        break;
      case _Edge.bottom:
        startPosition = Vector2(
          40 + random.nextDouble() * (size.x - 80),
          size.y + 40,
        );
        break;
      case _Edge.left:
        startPosition = Vector2(
          -40,
          160 + random.nextDouble() * (size.y - 330),
        );
        break;
    }

    // Ruoi thuong bay huong vao tam vung gameplay.
    final center = Vector2(size.x * 0.5, size.y * 0.55);
    var direction = center - startPosition;
    if (direction.length2 < 0.0001) {
      direction = Vector2(1, 0);
    } else {
      direction.normalize();
    }

    final speed =
        isBoss
            ? (45 + random.nextDouble() * 14) * _currentSpeedMultiplier
            : (58 + random.nextDouble() * 30) * _currentSpeedMultiplier;
    final bossHealth = _bossHealthForLevel;
    final bossDropDamage = _bossDamageForLevel;
    final bossPoints = 12 + (_difficultyLevel * 2);
    add(
      Fly(
        position: startPosition,
        game: this,
        flySize: isBoss ? 92 : 40 + random.nextDouble() * 20,
        pointValue: isBoss ? bossPoints : 2,
        initialVelocity: direction * speed,
        isBoss: isBoss,
        maxHealth: isBoss ? bossHealth : 1,
        canReproduce: !isBoss,
        speedMultiplier:
            isBoss ? _currentSpeedMultiplier * 0.92 : _currentSpeedMultiplier,
        droppingDamage: isBoss ? bossDropDamage : 1,
        dropIntervalScale: isBoss ? 0.72 : 1.0,
      ),
    );
  }

  void spawnFly({
    bool isMutant = false,
    Vector2? atPosition,
    Color? mutantColor,
  }) {
    final flyCount = children.whereType<Fly>().length;
    if (flyCount >= _maxTotalFlies) return;

    final x =
        atPosition?.x.clamp(50, size.x - 50) ??
        (random.nextDouble() * (size.x - 100) + 50);
    final y =
        atPosition?.y.clamp(150, size.y - 150) ??
        (random.nextDouble() * (size.y - 300) + 150);

    // Spawn ruoi mutan sinh ra khi va cham o phase cuoi game.
    if (isMutant) {
      if (_activeChildFlyCount >= _maxChildFlies) return;
      add(
        Fly(
          position: Vector2(x.toDouble(), y.toDouble()),
          game: this,
          flySize: 48,
          pointValue: 4,
          isMutant: true,
          canReproduce: false,
          speedMultiplier: _currentSpeedMultiplier + 0.08,
          mutantColor:
              mutantColor ??
              _mutantColors[random.nextInt(_mutantColors.length)],
        ),
      );
      return;
    }

    final sizes = [40.0, 55.0, 70.0];
    final points = [3, 2, 1];
    final sizeIndex = random.nextInt(sizes.length);

    add(
      Fly(
        position: Vector2(x.toDouble(), y.toDouble()),
        game: this,
        flySize: sizes[sizeIndex],
        pointValue: points[sizeIndex],
        speedMultiplier: _currentSpeedMultiplier,
      ),
    );
  }

  void _updatePendingCollisionSpawns(double dt) {
    if (_pendingCollisionSpawns.isEmpty) return;

    final completed = <_PendingCollisionSpawn>[];

    for (final pending in _pendingCollisionSpawns) {
      pending.remaining -= dt;
      if (pending.remaining > 0) continue;

      // Cho 2 ruoi dung tam thoi, sau delay moi tao ruoi con de gameplay de doc.
      final firstAlive =
          pending.first.parent != null && !pending.first.isSwatted;
      final secondAlive =
          pending.second.parent != null && !pending.second.isSwatted;

      if (firstAlive && secondAlive) {
        final liveFlyCount =
            children.whereType<Fly>().where((fly) => !fly.isSwatted).length;
        final availableSlots = (_maxTotalFlies - liveFlyCount).clamp(0, 1);
        final availableChildren = (_maxChildFlies - _activeChildFlyCount).clamp(
          0,
          1,
        );
        final midpoint = (pending.first.position + pending.second.position) / 2;
        final availableBirths = min(availableSlots, availableChildren);
        if (availableBirths >= 1) {
          const childCount = 1;
          for (int index = 0; index < childCount; index++) {
            final angle = random.nextDouble() * 2 * pi;
            final distance = 12 + random.nextDouble() * 22;
            final offset = Vector2(cos(angle), sin(angle)) * distance;
            spawnFly(isMutant: true, atPosition: midpoint + offset);
          }
        }

        var separationDir = pending.first.position - pending.second.position;
        if (separationDir.length2 < 0.0001) {
          final angle = random.nextDouble() * 2 * pi;
          separationDir = Vector2(cos(angle), sin(angle));
        }
        separationDir.normalize();
        pending.first.releaseCollisionLock(pushDirection: separationDir);
        pending.second.releaseCollisionLock(pushDirection: -separationDir);
      } else {
        pending.first.releaseCollisionLock();
        pending.second.releaseCollisionLock();
      }

      _lockedFlyIds.remove(identityHashCode(pending.first));
      _lockedFlyIds.remove(identityHashCode(pending.second));
      completed.add(pending);
    }

    _pendingCollisionSpawns.removeWhere(completed.contains);
  }

  void _handleFlyCollisionSpawn() {
    // Sau 120s moi bat dau co co che "sinh san" khi ruoi va cham.
    if (elapsedTime < 120) return;

    final activeFlies = children
        .whereType<Fly>()
        .where((fly) => !fly.isSwatted)
        .toList(growable: false);

    for (int i = 0; i < activeFlies.length; i++) {
      for (int j = i + 1; j < activeFlies.length; j++) {
        final first = activeFlies[i];
        final second = activeFlies[j];
        final collisionDistance = (first.flySize + second.flySize) * 0.32;
        if (first.position.distanceToSquared(second.position) >
            collisionDistance * collisionDistance) {
          continue;
        }

        if (_isFlyLocked(first) || _isFlyLocked(second)) {
          continue;
        }

        if (!first.canStartReproduction || !second.canStartReproduction) {
          continue;
        }

        final firstId = identityHashCode(first);
        final secondId = identityHashCode(second);
        _lockedFlyIds.add(firstId);
        _lockedFlyIds.add(secondId);
        first.lockForCollisionSpawn();
        second.lockForCollisionSpawn();
        _pendingCollisionSpawns.add(
          _PendingCollisionSpawn(first: first, second: second, remaining: 1.0),
        );
      }
    }
  }

  bool _isFlyLocked(Fly fly) {
    return _lockedFlyIds.contains(identityHashCode(fly));
  }

  void onFlyDamaged(
    Vector2 position, {
    required bool isBoss,
    required int remainingHealth,
    required int maxHealth,
  }) {
    if (!isBoss) return;
    add(
      FloatingRewardText(
        position: position.clone() + Vector2(0, -20),
        text: 'Boss $remainingHealth/$maxHealth',
        color: const Color(0xFFFF7043),
        lifetime: 0.45,
        riseSpeed: 22,
      ),
    );
  }

  void flySwatted(Vector2 position, int points, {bool wasBoss = false}) {
    score += points;
    combo++;
    _registerSwatBurst();
    final effectLoad = _effectLoadLevel();

    if (wasBoss) {
      // Ha boss: luon thuong 3 tool.
      _rewardToolsWithAnimation(
        position,
        count: 3,
        minDelay: 1.0,
        maxDelay: 1.4,
      );
      difficultyNotice?.show('Hạ boss! +3 công cụ');
    } else {
      _normalFlyDefeatCounter++;
      // Trung binh 20 ruoi thuong roi 1 lan thuong 1-3 tool.
      if (_normalFlyDefeatCounter >= 20) {
        _normalFlyDefeatCounter = 0;
        final toolCount = 1 + random.nextInt(3);
        _rewardToolsWithAnimation(
          position,
          count: toolCount,
          minDelay: 1.0,
          maxDelay: 2.0,
        );
      }
    }

    if (score > highScore) {
      highScore = score;
    }

    scoreCard.updateScore(score, combo, highScore);
    final particleBurst =
        wasBoss
            ? (effectLoad >= 2
                ? 8
                : effectLoad == 1
                ? 12
                : 16)
            : (effectLoad >= 2
                ? 2
                : effectLoad == 1
                ? 4
                : 8);
    _createParticles(position, burstCount: particleBurst);

    final allowText = wasBoss || effectLoad <= 1;
    if (allowText) {
      _spawnRewardText(
        position,
        points: points,
        isBoss: wasBoss,
        showComboText: effectLoad == 0 || wasBoss,
      );
    }

    // Reset combo neu 2 giay khong co lan ha ruoi tiep theo.
    _comboResetRemaining = 2.0;
  }

  void _activateBowlShield({required int hits}) {
    _bowlShieldHitPoints = max(_bowlShieldHitPoints, max(1, hits));
    noodleBowl.setShieldState(
      active: true,
      currentHits: _bowlShieldHitPoints,
      maxHits: _shieldMaxHitPoints,
    );
  }

  void _spawnRewardText(
    Vector2 position, {
    required int points,
    required bool isBoss,
    bool showComboText = true,
  }) {
    final text = isBoss ? '+$points BOSS' : '+$points';
    final color = isBoss ? const Color(0xFFFFA000) : const Color(0xFF43A047);
    add(
      FloatingRewardText(position: position.clone(), text: text, color: color),
    );

    if (showComboText && combo >= 3) {
      add(
        FloatingRewardText(
          position: position.clone() + Vector2(0, 16),
          text: 'Combo x$combo',
          color: const Color(0xFFE65100),
          lifetime: 0.55,
          riseSpeed: 18,
        ),
      );
    }
  }

  void _createParticles(Vector2 position, {int burstCount = 8}) {
    // Han che particle de tranh qua tai khi so luong ruoi lon.
    final aliveParticles = children.whereType<Particle>().length;
    if (aliveParticles > 50) return;

    for (int i = 0; i < burstCount; i++) {
      add(
        Particle(
          position: position.clone(),
          velocity: Vector2(
            (random.nextDouble() - 0.5) * 160,
            (random.nextDouble() - 0.5) * 160,
          ),
        ),
      );
    }
  }

  void spawnFlyDropping(
    Vector2 fromPosition, {
    Vector2? initialVelocity,
    int contaminationDamage = 1,
  }) {
    if (gameOver) return;
    add(
      FlyDropping(
        position: fromPosition,
        game: this,
        initialVelocity: initialVelocity,
        contaminationDamage: contaminationDamage,
      ),
    );
  }

  bool isPointInsideNoodleBowl(Vector2 worldPoint) {
    if (!_initialized || noodleBowl.parent == null) return false;
    return noodleBowl.containsWorldPoint(worldPoint);
  }

  void onNoodleBowlContaminated({int damageUnits = 1}) {
    if (gameOver) return;

    if (_bowlShieldHitPoints > 0) {
      _bowlShieldHitPoints = max(0, _bowlShieldHitPoints - max(1, damageUnits));
      noodleBowl.setShieldState(
        active: _bowlShieldHitPoints > 0,
        currentHits: _bowlShieldHitPoints,
        maxHits: _shieldMaxHitPoints,
      );
      add(
        ShieldBlockEffect(
          position:
              noodleBowl.position +
              Vector2(noodleBowl.size.x / 2, noodleBowl.size.y * 0.35),
        ),
      );
      return;
    }

    // Moi lan phan roi vao to mi se giam % sach.
    _noodleDropHits =
        (_noodleDropHits + max(1, damageUnits))
            .clamp(0, _maxNoodleDrops)
            .toInt();
    final cleanPercent = 100 - ((_noodleDropHits / _maxNoodleDrops) * 100);
    noodleBowl.setContaminationProgress(cleanPercent);

    if (_noodleDropHits >= _maxNoodleDrops) {
      _captureDefeatStats();
      gameOver = true;
      scoreCard.updateTime(_defeatSeconds);
      _endGame();
    }
  }

  void _captureDefeatStats() {
    if (_defeatStatsCaptured) return;
    _defeatStatsCaptured = true;

    _defeatSeconds = max(0, elapsedTime.floor());
    _defeatFlyCount =
        children.whereType<Fly>().where((fly) => !fly.isSwatted).length;
  }

  void _endGame() {
    if (_endingTriggered) return;
    _endingTriggered = true;

    _captureDefeatStats();

    // Delay nhe de nguoi choi thay frame ket thuc truoc khi chuyen man.
    Future.delayed(const Duration(milliseconds: 500), () {
      final context = buildContext;
      if (context != null && context.mounted) {
        ScoreRepository.instance.recordGameResult(
          playerProfile,
          score,
          DateTime.now(),
          defeatSeconds: _defeatSeconds,
          flyCountAtDefeat: _defeatFlyCount,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => GameOverScreen(
                  score: score,
                  highScore: highScore,
                  isNewRecord: score > startingBestScore,
                  defeatSeconds: _defeatSeconds,
                  flyCountAtDefeat: _defeatFlyCount,
                ),
          ),
        );
      }
    });
  }
}
