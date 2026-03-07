import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/player_profile.dart';
import '../screens/game_over_screen.dart';
import '../services/score_repository.dart';

part 'components/background_components.part.dart';
part 'components/fly_component.part.dart';
part 'components/hud_components.part.dart';
part 'components/world_components.part.dart';

/// Core game loop và toàn bộ component gameplay.
class FlySwatterGame extends FlameGame with HasCollisionDetection {
  final PlayerProfile playerProfile;
  final int startingBestScore;

  int score = 0;
  late int highScore;
  int combo = 0;
  double normalSpawnTimer = 0;
  double elapsedTime = 0;
  final Random random = Random();
  bool gameOver = false;
  bool _initialized = false;
  int _lastShownSecond = -1;
  int _comboResetVersion = 0;
  bool _endingTriggered = false;
  int _noodleDropHits = 0;
  bool _defeatStatsCaptured = false;
  int _defeatSeconds = 0;
  int _defeatFlyCount = 0;
  final List<_PendingCollisionSpawn> _pendingCollisionSpawns = [];
  final Set<int> _lockedFlyIds = <int>{};
  int _edgeSpawnCursor = 0;
  int _difficultyLevel = 0;
  final List<Color> _mutantColors = const [
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFFEF6C00),
    Color(0xFF3949AB),
  ];

  static const int _maxChildFlies = 100;
  static const int _maxTotalFlies = 240;
  static const int _maxNoodleDrops = 100;
  static const List<int> _difficultyStartSeconds = [
    0,
    60,
    120,
    180,
    240,
    300,
    360,
    420,
    480,
    540,
  ];
  static const List<int> _spawnCountByDifficulty = [
    2,
    4,
    4,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
  ];
  static const List<double> _spawnIntervalByDifficulty = [
    2.0,
    2.0,
    2.0,
    1.0,
    1.0,
    1.0,
    1.0,
    1.0,
    1.0,
    1.0,
  ];
  static const List<String> _difficultyLabels = [
    'Cấp 1',
    'Cấp 2',
    'Cấp 3',
    'Cấp 4',
    'Cấp 5',
    'Cấp 6',
    'Cấp 7',
    'Cấp 8',
    'Cấp 9',
    'Cấp 10',
  ];

  // So luong ruoi con dang ton tai (ruoi dot bien tu sinh san).
  int get _activeChildFlyCount =>
      children
          .whereType<Fly>()
          .where((fly) => fly.isMutant && !fly.isSwatted)
          .length;

  late ScoreCard scoreCard;
  late NoodleBowl noodleBowl;
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

    // Banner thong bao cap do kho.
    difficultyNotice = DifficultyNotice();
    add(difficultyNotice!);
    _updateDifficultyNoticePosition();

    _ensureInitialized();
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
  }

  void _ensureInitialized() {
    // Dam bao map chi duoc tao mot lan khi kich thuoc game da san sang.
    if (_initialized || size.x <= 0 || size.y <= 0) return;
    _initialized = true;
    _addBackgroundElements();
    _spawnInitialEdgeWave();
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

  @override
  void update(double dt) {
    super.update(dt);

    _ensureInitialized();

    if (gameOver) return;

    elapsedTime += dt;

    final currentSecond = elapsedTime.floor();
    if (currentSecond != _lastShownSecond) {
      _lastShownSecond = currentSecond;
      scoreCard.updateTime(currentSecond);
      _updateDifficultyByTime(currentSecond);
    }

    _updatePendingCollisionSpawns(dt);
    _handleFlyCollisionSpawn();

    // Spawn ruoi theo cap do kho hien tai.
    final spawnInterval = _spawnIntervalByDifficulty[_difficultyLevel];
    final spawnCount = _spawnCountByDifficulty[_difficultyLevel];

    normalSpawnTimer += dt;
    while (normalSpawnTimer >= spawnInterval) {
      normalSpawnTimer -= spawnInterval;
      _spawnNormalFliesFromEdges(count: spawnCount);
    }
  }

  int _resolveDifficultyLevel(int seconds) {
    for (int index = _difficultyStartSeconds.length - 1; index >= 0; index--) {
      if (seconds >= _difficultyStartSeconds[index]) {
        return index;
      }
    }
    return 0;
  }

  void _updateDifficultyByTime(int seconds) {
    final nextLevel = _resolveDifficultyLevel(seconds);
    if (nextLevel == _difficultyLevel) return;

    _difficultyLevel = nextLevel;
    difficultyNotice?.show(_difficultyLabels[nextLevel]);
  }

  void _spawnInitialEdgeWave() {
    _spawnNormalFliesFromEdges(count: _spawnCountByDifficulty[0]);
  }

  void _spawnNormalFliesFromEdges({required int count}) {
    for (int index = 0; index < count; index++) {
      final edge = _Edge.values[_edgeSpawnCursor % _Edge.values.length];
      _edgeSpawnCursor++;
      _spawnEdgeFly(edge);
    }
  }

  void _spawnEdgeFly(_Edge edge) {
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

    final speed = 58 + random.nextDouble() * 30;
    add(
      Fly(
        position: startPosition,
        game: this,
        flySize: 40 + random.nextDouble() * 20,
        pointValue: 2,
        initialVelocity: direction * speed,
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

  void flySwatted(Vector2 position, int points) {
    score += points;
    combo++;

    if (score > highScore) {
      highScore = score;
    }

    scoreCard.updateScore(score, combo, highScore);
    _createParticles(position);

    // Combo reset neu qua 2 giay khong dap tiep.
    _comboResetVersion++;
    final currentVersion = _comboResetVersion;
    Future.delayed(const Duration(seconds: 2), () {
      if (currentVersion != _comboResetVersion || gameOver) return;
      combo = 0;
      scoreCard.updateScore(score, 0, highScore);
    });
  }

  void _createParticles(Vector2 position) {
    // Han che particle de tranh qua tai khi so luong ruoi lon.
    final aliveParticles = children.whereType<Particle>().length;
    if (aliveParticles > 50) return;

    const burstCount = 8;
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

  void spawnFlyDropping(Vector2 fromPosition, {Vector2? initialVelocity}) {
    if (gameOver) return;
    add(
      FlyDropping(
        position: fromPosition,
        game: this,
        initialVelocity: initialVelocity,
      ),
    );
  }

  bool isPointInsideNoodleBowl(Vector2 worldPoint) {
    if (!_initialized || noodleBowl.parent == null) return false;
    return noodleBowl.containsWorldPoint(worldPoint);
  }

  void onNoodleBowlContaminated() {
    if (gameOver) return;

    // Moi lan phan roi vao to mi se giam % sach.
    _noodleDropHits = (_noodleDropHits + 1).clamp(0, _maxNoodleDrops);
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

enum _Edge { top, right, bottom, left }

class _PendingCollisionSpawn {
  final Fly first;
  final Fly second;
  double remaining;

  _PendingCollisionSpawn({
    required this.first,
    required this.second,
    required this.remaining,
  });
}
