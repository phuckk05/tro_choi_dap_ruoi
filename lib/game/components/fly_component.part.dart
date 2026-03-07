part of '../fly_swatter_game.dart';

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
  bool _dropLeftNext = true;

  double wingAngle = 0;
  double animationTime = 0;

  static final Paint _bloodPaint =
      Paint()
        ..color = const Color(0xFFb71c1c).withValues(alpha: 0.7)
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
      Paint()..color = Colors.white.withValues(alpha: 0.35);
  static final Paint _headPaint = Paint()..color = const Color(0xFF1a1a1a);
  static final Paint _eyePaint =
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, 5, [
          const Color(0xFFd32f2f),
          const Color(0xFFb71c1c),
        ]);
  static final Paint _eyeHighlightPaint =
      Paint()..color = Colors.white.withValues(alpha: 0.7);
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
        ..color = const Color(0xFF607D8B).withValues(alpha: 0.7)
        ..strokeWidth = 0.9;
  static final Paint _wingSubVeinPaint =
      Paint()
        ..color = const Color(0xFF607D8B).withValues(alpha: 0.45)
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
    // Neu co van toc khoi tao (spawn tu canh) thi giu huong do, khong random lai.
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

    // Phan roi xen ke trai/phai de nhin tu nhien hon.
    const visualCenterCorrectionX = -20.0;
    final side = _dropLeftNext ? -1.0 : 1.0;
    _dropLeftNext = !_dropLeftNext;
    final horizontalOffset =
        side * (flySize * (0.07 + random.nextDouble() * 0.1));
    final dropPosition =
        position +
        Vector2(visualCenterCorrectionX + horizontalOffset, flySize * 0.24);
    final dropVelocity = Vector2(
      velocity.x * 0.05 + (random.nextDouble() - 0.5) * 10,
      24 + max(0, velocity.y * 0.12),
    );
    game.spawnFlyDropping(dropPosition, initialVelocity: dropVelocity);
    _scheduleNextDrop();
  }

  void _changeDirection() {
    // Ruoi con (khong reproduce) nhanh hon ruoi thuong.
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

    // Dang bi khoa va cham thi dung yen cho den khi sinh san xong.
    if (_collisionLocked) {
      animationTime += dt * 12;
      wingAngle = sin(animationTime) * 0.12;
      return;
    }

    animationTime += dt * 15;
    wingAngle = sin(animationTime) * 0.22;

    position += velocity * dt;

    // Gioi han khu vuc bay trong khung gameplay.
    if (position.x < 50 || position.x > game.size.x - 50) {
      velocity.x = -velocity.x;
      position.x = position.x.clamp(50, game.size.x - 50);
    }
    if (position.y < 150 || position.y > game.size.y - 150) {
      velocity.y = -velocity.y;
      position.y = position.y.clamp(150, game.size.y - 150);
    }

    _updateDropTimer(dt);

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

    // Scale theo kich thuoc ruoi, bo phan ve sau dung toa do chuan.
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
      // Dap trung: cong diem + xoa sau 1 khoang ngan de hien hieu ung.
      isSwatted = true;
      velocity = Vector2.zero();
      game.flySwatted(position, pointValue);

      Future.delayed(const Duration(milliseconds: 800), () {
        removeFromParent();
      });
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    final hitRadius = (flySize * 0.5) + 14;
    return point.length2 <= hitRadius * hitRadius;
  }

  void lockForCollisionSpawn() {
    // Tam dung ruoi de mo phong "va cham" truoc khi tao ruoi con.
    _collisionLocked = true;
    velocity = Vector2.zero();
  }

  void releaseCollisionLock({Vector2? pushDirection}) {
    if (!_collisionLocked || isSwatted) return;
    _collisionLocked = false;

    // Day 2 ruoi ra xa nhau de tranh chong hinh/va cham lap.
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
