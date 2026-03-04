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

  int score = 0;
  static int highScore = 0;
  int combo = 0;
  double gameTime = 60.0;
  double spawnTimer = 0;
  final double spawnInterval = 0.8;
  final Random random = Random();
  bool gameOver = false;
  bool _initialized = false;
  int _lastShownSecond = 60;
  int _comboResetVersion = 0;

  late ScoreCard scoreCard;

  FlySwatterGame({required this.playerProfile});

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
  }

  void _ensureInitialized() {
    if (_initialized || size.x <= 0 || size.y <= 0) return;
    _initialized = true;
    _addBackgroundElements();
    for (int i = 0; i < 4; i++) {
      spawnFly();
    }
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
  }

  @override
  void update(double dt) {
    super.update(dt);

    _ensureInitialized();

    if (gameOver) return;

    gameTime -= dt;
    if (gameTime <= 0) {
      gameTime = 0;
      gameOver = true;
      _endGame();
      return;
    }

    final currentSecond = gameTime.ceil();
    if (currentSecond != _lastShownSecond) {
      _lastShownSecond = currentSecond;
      scoreCard.updateTime(currentSecond);
    }

    spawnTimer += dt;
    if (spawnTimer >= spawnInterval) {
      spawnTimer = 0;
      spawnFly();
    }
  }

  void spawnFly() {
    final flyCount = children.whereType<Fly>().length;
    if (flyCount >= 12) return;

    final x = random.nextDouble() * (size.x - 100) + 50;
    final y = random.nextDouble() * (size.y - 300) + 150;

    final sizes = [40.0, 55.0, 70.0];
    final points = [3, 2, 1];
    final sizeIndex = random.nextInt(sizes.length);

    add(
      Fly(
        position: Vector2(x, y),
        game: this,
        flySize: sizes[sizeIndex],
        pointValue: points[sizeIndex],
      ),
    );
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

  void _endGame() {
    Future.delayed(const Duration(milliseconds: 500), () {
      final context = buildContext;
      if (context != null && context.mounted) {
        ScoreRepository.instance.recordGameResult(
          playerProfile,
          score,
          DateTime.now(),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => GameOverScreen(score: score, highScore: highScore),
          ),
        );
      }
    });
  }
}

class Fly extends PositionComponent with TapCallbacks {
  final FlySwatterGame game;
  final double flySize;
  final int pointValue;
  final Random random = Random();
  Vector2 velocity = Vector2.zero();
  double changeDirectionTimer = 0;
  final double changeDirectionInterval = 1.5;
  bool isSwatted = false;

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
  }) : super(size: Vector2.all(flySize), anchor: Anchor.center, priority: 1);

  @override
  Future<void> onLoad() async {
    _changeDirection();
  }

  void _changeDirection() {
    final angle = random.nextDouble() * 2 * pi;
    final baseSpeed = 80.0 - (flySize - 40) * 0.5;
    final speed = baseSpeed + random.nextDouble() * 50;
    velocity = Vector2(cos(angle), sin(angle)) * speed;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isSwatted) return;

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

    canvas.save();
    canvas.translate(-14, -11);
    canvas.rotate(wingAngle);
    _drawWing(canvas);
    canvas.restore();

    canvas.save();
    canvas.translate(14, -11);
    canvas.scale(-1, 1);
    canvas.rotate(-wingAngle);
    _drawWing(canvas);
    canvas.restore();

    canvas.drawLine(const Offset(-9, -8), const Offset(-16, -3), _legPaint);
    canvas.drawLine(const Offset(9, -8), const Offset(16, -3), _legPaint);
    canvas.drawLine(const Offset(-9, 0), const Offset(-17, 6), _legPaint);
    canvas.drawLine(const Offset(9, 0), const Offset(17, 6), _legPaint);
    canvas.drawLine(const Offset(-8, 8), const Offset(-14, 14), _legPaint);
    canvas.drawLine(const Offset(8, 8), const Offset(14, 14), _legPaint);

    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 24, height: 36),
      _bodyPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-4, -8), width: 10, height: 16),
      _bodyHighlightPaint,
    );

    canvas.drawCircle(const Offset(0, -18), 11, _headPaint);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-5, -18), width: 9, height: 10),
      _eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(5, -18), width: 9, height: 10),
      _eyePaint,
    );

    canvas.drawCircle(const Offset(-4, -19), 2.5, _eyeHighlightPaint);
    canvas.drawCircle(const Offset(6, -19), 2.5, _eyeHighlightPaint);

    canvas.restore();
  }

  void _drawWing(Canvas canvas) {
    canvas.drawPath(_wingPath, _wingFillPaint);
    canvas.drawPath(_wingPath, _wingStrokePaint);

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
      text: '⏱️ 60',
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
        seconds <= 10
            ? 2
            : seconds <= 30
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
