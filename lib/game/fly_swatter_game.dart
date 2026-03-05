import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/player_profile.dart';
import '../screens/game_over_screen.dart';
import '../services/score_repository.dart';

/// Core game loop và toàn bộ component gameplay.
///
/// Giữ cùng 1 file để các thành phần phụ thuộc chặt chẽ vào nhau
/// (spawn/update/render) dễ theo dõi trong quá trình bảo trì.
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
  final List<Color> _mutantColors = const [
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFFEF6C00),
    Color(0xFF3949AB),
  ];
  static const int _maxChildFlies = 100;
  static const int _maxTotalFlies = 240;
  static const int _maxNoodleDrops = 100;

  int get _activeChildFlyCount =>
      children
          .whereType<Fly>()
          .where((fly) => fly.isMutant && !fly.isSwatted)
          .length;

  late ScoreCard scoreCard;
  late NoodleBowl noodleBowl;

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

    scoreCard = ScoreCard(position: Vector2(10, 10), game: this);
    add(scoreCard);

    _ensureInitialized();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _ensureInitialized();
    if (_initialized && noodleBowl.parent != null) {
      _updateNoodleBowlPosition();
    }
  }

  void _ensureInitialized() {
    if (_initialized || size.x <= 0 || size.y <= 0) return;
    _initialized = true;
    _addBackgroundElements();
    _spawnInitialEdgeWave();
  }

  void _addBackgroundElements() {
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
    }

    _updatePendingCollisionSpawns(dt);
    _handleFlyCollisionSpawn();

    normalSpawnTimer += dt;
    while (normalSpawnTimer >= 1.0) {
      normalSpawnTimer -= 1.0;
      _spawnNormalFliesFromEdges(count: 2);
    }
  }

  void _spawnInitialEdgeWave() {
    _spawnEdgeFly(_Edge.top);
    _spawnEdgeFly(_Edge.right);
    _spawnEdgeFly(_Edge.bottom);
    _spawnEdgeFly(_Edge.left);
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

    _comboResetVersion++;
    final currentVersion = _comboResetVersion;
    Future.delayed(const Duration(seconds: 2), () {
      if (currentVersion != _comboResetVersion || gameOver) return;
      combo = 0;
      scoreCard.updateScore(score, 0, highScore);
    });
  }

  void _createParticles(Vector2 position) {
    final aliveParticles = children.whereType<Particle>().length;
    if (aliveParticles > 50) return;

    final burstCount = 8;
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

  void spawnFlyDropping(Vector2 fromPosition) {
    if (gameOver) return;
    add(FlyDropping(position: fromPosition, game: this));
  }

  bool isPointInsideNoodleBowl(Vector2 worldPoint) {
    if (!_initialized || noodleBowl.parent == null) return false;
    return noodleBowl.containsWorldPoint(worldPoint);
  }

  void onNoodleBowlContaminated() {
    if (gameOver) return;

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

class Fly extends PositionComponent with TapCallbacks {
  final FlySwatterGame game;
  final double flySize;
  final int pointValue;
  final bool isMutant;
  final bool canReproduce;
  final Color mutantColor;
  final Vector2? initialVelocity;
  final Random random = Random();
  Vector2 velocity = Vector2.zero();
  double changeDirectionTimer = 0;
  final double changeDirectionInterval = 1.5;
  bool isSwatted = false;
  bool _collisionLocked = false;
  double _reproduceCooldown = 0;
  double _dropTimer = 0;
  double _nextDropInterval = 3.0;

  double wingAngle = 0;
  double animationTime = 0;

  static final Paint _bloodPaint =
      Paint()
        ..color = const Color(0xFFb71c1c).withOpacity(0.7)
        ..style = PaintingStyle.fill;
  static final Paint _xPaint =
      Paint()
        ..color = Colors.red
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
  static final Paint _legPaint =
      Paint()
        ..color = const Color(0xFF1a1a1a)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
  static final Paint _bodyPaint =
      Paint()
        ..shader = ui.Gradient.radial(const Offset(-3, -5), 20, [
          const Color(0xFF2a2a2a),
          const Color(0xFF000000),
        ]);
  static final Paint _bodyHighlightPaint =
      Paint()..color = Colors.white.withOpacity(0.35);
  static final Paint _headPaint = Paint()..color = const Color(0xFF1a1a1a);
  static final Paint _eyePaint =
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, 5, [
          const Color(0xFFd32f2f),
          const Color(0xFFb71c1c),
        ]);
  static final Paint _eyeHighlightPaint =
      Paint()..color = Colors.white.withOpacity(0.7);
  static final Paint _wingFillPaint =
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          const Offset(28, 12),
          [
            const Color(0xFFF5F5F5),
            const Color(0xFFDCE3EA),
            const Color(0xFFB0BEC5),
          ],
          [0.0, 0.6, 1.0],
        )
        ..style = PaintingStyle.fill;
  static final Paint _wingStrokePaint =
      Paint()
        ..color = const Color(0xFF78909C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
  static final Paint _wingVeinPaint =
      Paint()
        ..color = const Color(0xFF607D8B).withOpacity(0.7)
        ..strokeWidth = 0.9;
  static final Paint _wingSubVeinPaint =
      Paint()
        ..color = const Color(0xFF607D8B).withOpacity(0.45)
        ..strokeWidth = 0.7;
  static final Path _wingPath =
      Path()
        ..moveTo(0, 0)
        ..cubicTo(10, -5, 21, -3, 28, 0)
        ..cubicTo(31, 3, 29, 10, 21, 11)
        ..cubicTo(12, 12, 4, 10, 0, 6)
        ..cubicTo(-1, 3, -1, 1, 0, 0)
        ..close();

  Fly({
    required super.position,
    required this.game,
    this.flySize = 60.0,
    this.pointValue = 1,
    this.isMutant = false,
    this.canReproduce = true,
    this.mutantColor = const Color(0xFF8E24AA),
    this.initialVelocity,
  }) : super(size: Vector2.all(flySize), anchor: Anchor.center, priority: 1);

  @override
  Future<void> onLoad() async {
    if (initialVelocity != null && initialVelocity!.length2 > 0) {
      velocity = initialVelocity!.clone();
    } else {
      _changeDirection();
    }
    _scheduleNextDrop(initial: true);
  }

  void _scheduleNextDrop({bool initial = false}) {
    _nextDropInterval = 2.6 + random.nextDouble() * 0.8;
    _dropTimer = initial ? random.nextDouble() * 1.1 : 0;
  }

  void _updateDropTimer(double dt) {
    if (game.gameOver) return;

    _dropTimer += dt;
    if (_dropTimer < _nextDropInterval) return;

    final dropPosition = position + Vector2(0, flySize * 0.34);
    game.spawnFlyDropping(dropPosition);
    _scheduleNextDrop();
  }

  void _changeDirection() {
    final angle = random.nextDouble() * 2 * pi;
    final baseSpeed = (canReproduce ? 54.0 : 74.0) - (flySize - 40) * 0.4;
    final speed = baseSpeed + random.nextDouble() * (canReproduce ? 26 : 42);
    velocity = Vector2(cos(angle), sin(angle)) * speed;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isSwatted) return;

    if (_reproduceCooldown > 0) {
      _reproduceCooldown -= dt;
      if (_reproduceCooldown < 0) {
        _reproduceCooldown = 0;
      }
    }

    _updateDropTimer(dt);

    if (_collisionLocked) {
      animationTime += dt * 12;
      wingAngle = sin(animationTime) * 0.12;
      return;
    }

    animationTime += dt * 15;
    wingAngle = sin(animationTime) * 0.22;

    position += velocity * dt;

    if (position.x < 50 || position.x > game.size.x - 50) {
      velocity.x = -velocity.x;
      position.x = position.x.clamp(50, game.size.x - 50);
    }
    if (position.y < 150 || position.y > game.size.y - 150) {
      velocity.y = -velocity.y;
      position.y = position.y.clamp(150, game.size.y - 150);
    }

    changeDirectionTimer += dt;
    if (changeDirectionTimer >= changeDirectionInterval) {
      changeDirectionTimer = 0;
      if (random.nextDouble() < 0.5) {
        _changeDirection();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (isSwatted) {
      canvas.drawCircle(Offset.zero, 25, _bloodPaint);
      canvas.drawLine(const Offset(-20, -20), const Offset(20, 20), _xPaint);
      canvas.drawLine(const Offset(20, -20), const Offset(-20, 20), _xPaint);
      return;
    }

    canvas.save();
    final scale = flySize / 55;
    canvas.scale(scale, scale);

    final bodyPaint =
        isMutant
            ? (Paint()
              ..shader = ui.Gradient.radial(const Offset(-3, -5), 20, [
                mutantColor.withValues(alpha: 0.95),
                const Color(0xFF1A1A1A),
              ]))
            : _bodyPaint;
    final headPaint = isMutant ? (Paint()..color = mutantColor) : _headPaint;
    final eyePaint =
        isMutant
            ? (Paint()
              ..shader = ui.Gradient.radial(Offset.zero, 5, [
                mutantColor.withValues(alpha: 0.9),
                mutantColor.withValues(alpha: 0.55),
              ]))
            : _eyePaint;
    final wingFillPaint =
        isMutant
            ? (Paint()
              ..shader = ui.Gradient.linear(
                const Offset(0, 0),
                const Offset(28, 12),
                [
                  mutantColor.withValues(alpha: 0.8),
                  mutantColor.withValues(alpha: 0.45),
                  const Color(0xFFCFD8DC),
                ],
                [0.0, 0.55, 1.0],
              )
              ..style = PaintingStyle.fill)
            : _wingFillPaint;

    final wingStrokePaint =
        isMutant
            ? (Paint()
              ..color = mutantColor.withValues(alpha: 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2)
            : _wingStrokePaint;
    final wingVeinPaint =
        isMutant
            ? (Paint()
              ..color = mutantColor.withValues(alpha: 0.7)
              ..strokeWidth = 0.9)
            : _wingVeinPaint;
    final wingSubVeinPaint =
        isMutant
            ? (Paint()
              ..color = mutantColor.withValues(alpha: 0.48)
              ..strokeWidth = 0.7)
            : _wingSubVeinPaint;

    canvas.save();
    canvas.translate(-14, -11);
    canvas.rotate(wingAngle);
    _drawWing(
      canvas,
      wingFillPaint,
      wingStrokePaint,
      wingVeinPaint,
      wingSubVeinPaint,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(14, -11);
    canvas.scale(-1, 1);
    canvas.rotate(-wingAngle);
    _drawWing(
      canvas,
      wingFillPaint,
      wingStrokePaint,
      wingVeinPaint,
      wingSubVeinPaint,
    );
    canvas.restore();

    canvas.drawLine(const Offset(-9, -8), const Offset(-16, -3), _legPaint);
    canvas.drawLine(const Offset(9, -8), const Offset(16, -3), _legPaint);
    canvas.drawLine(const Offset(-9, 0), const Offset(-17, 6), _legPaint);
    canvas.drawLine(const Offset(9, 0), const Offset(17, 6), _legPaint);
    canvas.drawLine(const Offset(-8, 8), const Offset(-14, 14), _legPaint);
    canvas.drawLine(const Offset(8, 8), const Offset(14, 14), _legPaint);

    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 24, height: 36),
      bodyPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-4, -8), width: 10, height: 16),
      _bodyHighlightPaint,
    );

    canvas.drawCircle(const Offset(0, -18), 11, headPaint);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-5, -18), width: 9, height: 10),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(5, -18), width: 9, height: 10),
      eyePaint,
    );

    canvas.drawCircle(const Offset(-4, -19), 2.5, _eyeHighlightPaint);
    canvas.drawCircle(const Offset(6, -19), 2.5, _eyeHighlightPaint);

    canvas.restore();
  }

  void _drawWing(
    Canvas canvas,
    Paint wingFillPaint,
    Paint wingStrokePaint,
    Paint wingVeinPaint,
    Paint wingSubVeinPaint,
  ) {
    canvas.drawPath(_wingPath, wingFillPaint);
    canvas.drawPath(_wingPath, wingStrokePaint);

    canvas.drawLine(const Offset(1, 2), const Offset(24, 2), _wingVeinPaint);
    canvas.drawLine(const Offset(1, 5), const Offset(20, 8), _wingVeinPaint);
    canvas.drawLine(const Offset(3, 1), const Offset(14, 9), _wingVeinPaint);

    canvas.drawLine(const Offset(8, 1), const Offset(14, 4), _wingSubVeinPaint);
    canvas.drawLine(
      const Offset(10, 4),
      const Offset(17, 7),
      _wingSubVeinPaint,
    );
    canvas.drawLine(
      const Offset(13, 1),
      const Offset(20, 8),
      _wingSubVeinPaint,
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!isSwatted) {
      isSwatted = true;
      velocity = Vector2.zero();
      game.flySwatted(position, pointValue);

      Future.delayed(const Duration(milliseconds: 800), () {
        removeFromParent();
      });
    }
  }

  void lockForCollisionSpawn() {
    _collisionLocked = true;
    velocity = Vector2.zero();
  }

  void releaseCollisionLock({Vector2? pushDirection}) {
    if (!_collisionLocked || isSwatted) return;
    _collisionLocked = false;

    final direction = pushDirection;
    if (direction != null && direction.length2 > 0) {
      final normalized = direction.normalized();
      velocity = normalized * (130 + random.nextDouble() * 40);
      position += normalized * 10;
    } else {
      _changeDirection();
    }

    _reproduceCooldown = 0.85;
  }

  bool get canStartReproduction =>
      canReproduce && !_collisionLocked && _reproduceCooldown <= 0;
}

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

class Cloud extends PositionComponent {
  static final Paint _cloudPaint =
      Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..style = PaintingStyle.fill;

  final Random random = Random();
  late double speed;

  Cloud({required super.position})
    : super(size: Vector2(80 + Random().nextDouble() * 40, 40), priority: -10);

  @override
  Future<void> onLoad() async {
    speed = 10 + random.nextDouble() * 20;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += speed * dt;

    final game = parent as FlySwatterGame;
    if (position.x > game.size.x + size.x) {
      position.x = -size.x;
      position.y = random.nextDouble() * game.size.y * 0.4;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(const Offset(20, 0), 20, _cloudPaint);
    canvas.drawCircle(const Offset(40, -5), 25, _cloudPaint);
    canvas.drawCircle(const Offset(60, 0), 22, _cloudPaint);
    canvas.drawCircle(const Offset(50, 10), 18, _cloudPaint);
    canvas.drawCircle(const Offset(30, 8), 18, _cloudPaint);
  }
}

class Grass extends PositionComponent {
  late Paint _grassPaint;
  late final List<Path> _bladePaths;
  late final List<Paint> _bladePaints;

  Grass({required super.position}) : super(priority: -5);

  @override
  Future<void> onLoad() async {
    final game = parent as FlySwatterGame;
    size = Vector2(game.size.x, 80);

    _grassPaint =
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, 0), Offset(0, size.y), [
            const Color(0xFF4CAF50),
            const Color(0xFF66BB6A),
          ]);

    _bladePaths = <Path>[];
    _bladePaints = <Paint>[];

    final random = Random(42);
    for (int i = 0; i < size.x; i += 15) {
      final x = i.toDouble();
      final height = 20 + random.nextDouble() * 15;
      final greenShade = random.nextInt(3);
      final color =
          [
            const Color(0xFF388E3C),
            const Color(0xFF43A047),
            const Color(0xFF2E7D32),
          ][greenShade];

      final path =
          Path()
            ..moveTo(x, size.y)
            ..quadraticBezierTo(
              x + random.nextDouble() * 6 - 3,
              size.y - height / 2,
              x + random.nextDouble() * 8 - 4,
              size.y - height,
            );

      _bladePaths.add(path);
      _bladePaints.add(
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _grassPaint);

    for (int i = 0; i < _bladePaths.length; i++) {
      canvas.drawPath(_bladePaths[i], _bladePaints[i]);
    }
  }
}

class NoodleBowl extends PositionComponent {
  static final Paint _shadowPaint =
      Paint()
        ..color = const Color(0x33000000)
        ..style = PaintingStyle.fill;
  static final Paint _rimPaint =
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -16),
          const Offset(0, 16),
          [const Color(0xFFFDFDFD), const Color(0xFFD9E0E6)],
        )
        ..style = PaintingStyle.fill;
  static final Paint _outerPaint =
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -20),
          const Offset(0, 26),
          [const Color(0xFFD84315), const Color(0xFFBF360C)],
        )
        ..style = PaintingStyle.fill;
  static final Paint _highlightPaint =
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.fill;
  static final Paint _innerSoupPaint =
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -18),
          const Offset(0, 10),
          [const Color(0xFFFFD180), const Color(0xFFFFA726)],
        )
        ..style = PaintingStyle.fill;
  static final Paint _noodlePaint =
      Paint()
        ..color = const Color(0xFFFFF59D)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
  static final Paint _steamPaint =
      Paint()
        ..color = const Color(0x88FFFFFF)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
  double _steamTime = 0;
  double _contaminationPercent = 0;
  late TextPainter _percentPainter;

  NoodleBowl({required super.position})
    : super(size: Vector2(190, 80), anchor: Anchor.topLeft, priority: -3) {
    _percentPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
  }

  void setContaminationProgress(double percent) {
    _contaminationPercent = percent.clamp(0, 100);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _steamTime += dt;
  }

  bool containsWorldPoint(Vector2 worldPoint) {
    final local = (worldPoint - position) - Vector2(size.x / 2, size.y);
    final bowlTop = -70.0;
    return local.x >= -72 &&
        local.x <= 72 &&
        local.y >= bowlTop &&
        local.y <= -28;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    canvas.translate(0, -54);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 29), width: 174, height: 24),
      _shadowPaint,
    );

    for (int i = 0; i < 4; i++) {
      final baseX = -45.0 + (i * 30.0);
      final lift = sin(_steamTime * 1.8 + i) * 5;
      final steamPath =
          Path()
            ..moveTo(baseX, -14)
            ..cubicTo(
              baseX - 8,
              -30 + lift,
              baseX + 8,
              -50 + lift,
              baseX - 2,
              -68 + lift,
            );
      canvas.drawPath(steamPath, _steamPaint);
    }

    final outerRect = Rect.fromCenter(
      center: const Offset(0, 12),
      width: 168,
      height: 58,
    );
    final rimRect = Rect.fromCenter(
      center: const Offset(0, -2),
      width: 148,
      height: 32,
    );

    canvas.drawOval(outerRect, _outerPaint);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 4), width: 124, height: 16),
      _highlightPaint,
    );
    canvas.drawOval(rimRect, _rimPaint);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -2), width: 132, height: 23),
      _innerSoupPaint,
    );

    for (int i = -3; i <= 3; i++) {
      final baseX = i * 17.0;
      final path =
          Path()
            ..moveTo(baseX - 12, -2)
            ..quadraticBezierTo(baseX - 5, -8, baseX + 2, -2)
            ..quadraticBezierTo(baseX + 9, 4, baseX + 14, -1);
      canvas.drawPath(path, _noodlePaint);
    }

    final percentText = 'Mỳ sạch: ${_contaminationPercent.round()}%';
    _percentPainter.text = TextSpan(
      text: percentText,
      style: const TextStyle(
        color: Color(0xFF1B1F23),
        fontSize: 14,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(color: Color(0x55FFFFFF), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
    );
    _percentPainter.layout();
    _percentPainter.paint(canvas, Offset(-_percentPainter.width / 2, 38));

    canvas.restore();
  }
}

class FlyDropping extends PositionComponent {
  final FlySwatterGame game;
  Vector2 velocity = Vector2(0, 30);

  static final Paint _dropPaint =
      Paint()
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.fill;

  FlyDropping({required super.position, required this.game})
    : super(size: Vector2.all(6), anchor: Anchor.center, priority: 1);

  @override
  void update(double dt) {
    super.update(dt);

    velocity.y += 520 * dt;
    position += velocity * dt;

    if (game.isPointInsideNoodleBowl(position)) {
      removeFromParent();
      game.onNoodleBowlContaminated();
      return;
    }

    if (position.y > game.size.y + 30 ||
        position.x < -30 ||
        position.x > game.size.x + 30) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 5, height: 7),
      _dropPaint,
    );
  }
}

class Particle extends PositionComponent {
  Vector2 velocity;
  double life = 1.0;
  late Color color;
  final Random random = Random();
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  static const List<Color> _particleColors = [
    Color(0xFFe74c3c),
    Color(0xFFf39c12),
    Color(0xFFe67e22),
    Color(0xFFc0392b),
  ];

  Particle({required super.position, required this.velocity})
    : super(size: Vector2.all(6), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    color = _particleColors[random.nextInt(_particleColors.length)];
    _paint.color = color;
  }

  @override
  void update(double dt) {
    super.update(dt);

    position += velocity * dt;
    velocity.y += 300 * dt;
    life -= dt * 2;

    _paint.color = color.withOpacity(life.clamp(0, 1));

    if (life <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, size.x / 2, _paint);
  }
}

class ScoreCard extends PositionComponent {
  final FlySwatterGame game;
  late TextComponent scoreText;
  late TextComponent comboText;
  late TextComponent timeText;
  int _lastShownTime = -1;
  int _timeLevel = 0;
  late final TextPaint _timeNormalPaint;
  late final TextPaint _timeWarningPaint;
  late final TextPaint _timeCriticalPaint;
  late final RRect _cardRRect;
  late final Paint _cardShadowPaint;
  late final Paint _cardFillPaint;
  late final Paint _cardBorderPaint;

  ScoreCard({required super.position, required this.game})
    : super(size: Vector2(140, 55), anchor: Anchor.topLeft, priority: 2);

  @override
  Future<void> onLoad() async {
    _timeNormalPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFFFF5722),
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
    );
    _timeWarningPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFFFF9800),
        fontSize: 26,
        fontWeight: FontWeight.w900,
      ),
    );
    _timeCriticalPaint = TextPaint(
      style: const TextStyle(
        color: Color(0xFFd32f2f),
        fontSize: 26,
        fontWeight: FontWeight.w900,
      ),
    );

    _cardRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(15),
    );
    _cardShadowPaint = Paint()..color = Colors.black.withOpacity(0.12);
    _cardFillPaint =
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, 0), Offset(0, size.y), [
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.86),
          ]);
    _cardBorderPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    timeText = TextComponent(
      text: '⏱️ 0',
      position: Vector2(8, 14),
      anchor: Anchor.centerLeft,
      textRenderer: _timeNormalPaint,
    );
    add(timeText);

    scoreText = TextComponent(
      text: '🏆 0',
      position: Vector2(8, 40),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF1976D2),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    add(scoreText);

    comboText = TextComponent(
      text: '',
      position: Vector2(95, 40),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFF6F00),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    add(comboText);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(_cardRRect.shift(const Offset(0, 2)), _cardShadowPaint);
    canvas.drawRRect(_cardRRect, _cardFillPaint);
    canvas.drawRRect(_cardRRect, _cardBorderPaint);

    super.render(canvas);
  }

  void updateScore(int score, int combo, int highScore) {
    scoreText.text = '🏆 $score';

    if (combo > 1) {
      comboText.text = 'x$combo🔥';
    } else {
      comboText.text = '';
    }
  }

  void updateTime(int seconds) {
    if (seconds == _lastShownTime) return;
    _lastShownTime = seconds;
    timeText.text = '⏱️ $seconds';

    final nextLevel =
        seconds >= 50
            ? 2
            : seconds >= 30
            ? 1
            : 0;
    if (nextLevel != _timeLevel) {
      _timeLevel = nextLevel;
      timeText.textRenderer =
          nextLevel == 2
              ? _timeCriticalPaint
              : nextLevel == 1
              ? _timeWarningPaint
              : _timeNormalPaint;
    }
  }
}

class Sun extends PositionComponent {
  double rotationAngle = 0;

  static final Paint _glowPaint =
      Paint()..color = Colors.orange.withOpacity(0.12);
  static final Paint _rayPaint =
      Paint()
        ..color = const Color(0xFFFFD700)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
  static final Paint _corePaint =
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          30,
          [
            const Color(0xFFFFEB3B),
            const Color(0xFFFFD700),
            const Color(0xFFFFA500),
          ],
          [0.0, 0.5, 1.0],
        );
  static final Paint _highlightPaint =
      Paint()..color = Colors.white.withOpacity(0.4);
  static final List<Offset> _rayStarts = List<Offset>.generate(12, (i) {
    final angle = (i * 30) * pi / 180;
    return Offset(cos(angle) * 30, sin(angle) * 30);
  });
  static final List<Offset> _rayEnds = List<Offset>.generate(12, (i) {
    final angle = (i * 30) * pi / 180;
    return Offset(cos(angle) * 45, sin(angle) * 45);
  });

  Sun({required super.position})
    : super(size: Vector2.all(80), anchor: Anchor.center, priority: -15);

  @override
  void update(double dt) {
    super.update(dt);
    rotationAngle += dt * 0.5;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();

    canvas.drawCircle(Offset.zero, 50, _glowPaint);

    canvas.rotate(rotationAngle);
    for (int i = 0; i < 12; i++) {
      canvas.drawLine(_rayStarts[i], _rayEnds[i], _rayPaint);
    }

    canvas.restore();

    canvas.drawCircle(Offset.zero, 30, _corePaint);
    canvas.drawCircle(const Offset(-8, -8), 12, _highlightPaint);
  }
}

class Bush extends PositionComponent {
  static final Paint _bushPaint = Paint()..color = const Color(0xFF2E7D32);
  static final Paint _darkBushPaint = Paint()..color = const Color(0xFF1B5E20);
  static final Paint _highlightPaint =
      Paint()..color = const Color(0xFF4CAF50).withOpacity(0.6);

  Bush({required super.position})
    : super(size: Vector2(60, 40), anchor: Anchor.bottomCenter, priority: -6);

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(const Offset(10, 0), 18, _darkBushPaint);
    canvas.drawCircle(const Offset(50, -5), 20, _darkBushPaint);
    canvas.drawCircle(const Offset(30, -10), 16, _darkBushPaint);

    canvas.drawCircle(const Offset(15, -8), 16, _bushPaint);
    canvas.drawCircle(const Offset(35, -12), 18, _bushPaint);
    canvas.drawCircle(const Offset(45, -5), 15, _bushPaint);
    canvas.drawCircle(const Offset(25, -5), 14, _bushPaint);

    canvas.drawCircle(const Offset(20, -10), 8, _highlightPaint);
    canvas.drawCircle(const Offset(38, -14), 7, _highlightPaint);
  }
}
