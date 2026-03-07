part of '../fly_swatter_game.dart';

class Fly extends PositionComponent with TapCallbacks {
  final FlySwatterGame game;
  final double flySize;
  final int pointValue;
  final bool isMutant;
  final bool isBoss;
  final bool canReproduce;
  final int maxHealth;
  final double speedMultiplier;
  final int droppingDamage;
  final double dropIntervalScale;
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
  int _health = 1;
  double _hitFlash = 0;
  bool _exiting = false;
  bool _absorbingIntoBoss = false;
  Fly? _absorbTargetBoss;
  double _absorbProgress = 0;
  int _bonusMaxHealth = 0;
  int _bonusDropDamage = 0;
  int _absorbedFlyCount = 0;
  double _empowerPulse = 0;
  double _swatElapsed = 0;
  static const double _swatDuration = 0.62;
  final List<_SplatBlob> _splatBlobs = <_SplatBlob>[];
  final List<_SplatLine> _splatLines = <_SplatLine>[];

  double wingAngle = 0;
  double animationTime = 0;

  int get _effectiveMaxHealth => maxHealth + _bonusMaxHealth;
  int get _effectiveDropDamage => droppingDamage + _bonusDropDamage;
  double get _bossGrowthScale =>
      isBoss ? (1 + min(0.42, _absorbedFlyCount * 0.018)) : 1;

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
    this.isBoss = false,
    this.canReproduce = true,
    this.maxHealth = 1,
    this.speedMultiplier = 1.0,
    this.droppingDamage = 1,
    this.dropIntervalScale = 1.0,
    this.mutantColor = const Color(0xFF8E24AA),
    this.initialVelocity,
  }) : super(size: Vector2.all(flySize), anchor: Anchor.center, priority: 1);

  @override
  Future<void> onLoad() async {
    _health = max(1, maxHealth);

    // Neu co van toc khoi tao (spawn tu canh) thi giu huong do, khong random lai.
    if (initialVelocity != null && initialVelocity!.length2 > 0) {
      velocity = initialVelocity!.clone();
    } else {
      _changeDirection();
    }
    _scheduleNextDrop(initial: true);
  }

  void _scheduleNextDrop({bool initial = false}) {
    _nextDropInterval = (2.6 + random.nextDouble() * 0.8) * dropIntervalScale;
    _dropTimer = initial ? random.nextDouble() * 1.1 : 0;
  }

  void _updateDropTimer(double dt) {
    if (game.gameOver || _exiting || _absorbingIntoBoss) return;

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
    game.spawnFlyDropping(
      dropPosition,
      initialVelocity: dropVelocity,
      contaminationDamage: _effectiveDropDamage,
    );
    _scheduleNextDrop();
  }

  void _changeDirection() {
    // Ruoi con (khong reproduce) nhanh hon ruoi thuong.
    final angle = random.nextDouble() * 2 * pi;
    final baseSpeed =
        ((canReproduce ? 54.0 : 74.0) - (flySize - 40) * 0.4) * speedMultiplier;
    final speed = baseSpeed + random.nextDouble() * (canReproduce ? 26 : 42);
    velocity = Vector2(cos(angle), sin(angle)) * speed;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isSwatted) {
      _swatElapsed += dt;
      if (_swatElapsed >= _swatDuration) {
        removeFromParent();
      }
      return;
    }

    if (_hitFlash > 0) {
      _hitFlash = max(0, _hitFlash - dt * 5);
    }

    if (_reproduceCooldown > 0) {
      _reproduceCooldown -= dt;
      if (_reproduceCooldown < 0) {
        _reproduceCooldown = 0;
      }
    }

    if (_empowerPulse > 0) {
      _empowerPulse = max(0, _empowerPulse - dt * 2.2);
    }

    if (_absorbingIntoBoss) {
      _updateAbsorbIntoBoss(dt);
      return;
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

    if (_exiting) {
      final margin = 120.0;
      if (position.x < -margin ||
          position.x > game.size.x + margin ||
          position.y < -margin ||
          position.y > game.size.y + margin) {
        removeFromParent();
      }
      return;
    }

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
      final t = (_swatElapsed / _swatDuration).clamp(0, 1).toDouble();
      final squashX = 1.0 + (t * 0.55);
      final squashY = 1.0 - (t * 0.72);
      final corePaint =
          Paint()
            ..color = const Color(0xFF9a1b1b).withValues(alpha: 0.86 - t * 0.56)
            ..style = PaintingStyle.fill;
      final darkCorePaint =
          Paint()
            ..color = const Color(0xFF5f0f0f).withValues(alpha: 0.72 - t * 0.5)
            ..style = PaintingStyle.fill;

      canvas.save();
      canvas.scale(squashX, max(0.12, squashY));
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 44 + (t * 22), height: 26),
        corePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(2, 1), width: 26, height: 16),
        darkCorePaint,
      );
      canvas.restore();

      final blobPaint =
          Paint()
            ..color = const Color(0xFF7f0000).withValues(alpha: 0.82 - t * 0.54)
            ..style = PaintingStyle.fill;
      for (final blob in _splatBlobs) {
        final px = blob.origin.dx + (blob.drift.dx * t);
        final py = blob.origin.dy + (blob.drift.dy * t);
        final radius = blob.radius * (1 + t * 0.9);
        canvas.drawCircle(Offset(px, py), radius, blobPaint);
      }

      final legPaint =
          Paint()
            ..color = const Color(0xFF2A1818).withValues(alpha: 0.8 - t * 0.58)
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round;
      for (final line in _splatLines) {
        final start = line.start + line.drift * t;
        final end = line.end + line.drift * t;
        canvas.drawLine(start, end, legPaint);
      }

      final wetHighlight =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.24 - t * 0.18)
            ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(-7 - t * 2, -3), width: 13, height: 6),
        wetHighlight,
      );
      return;
    }

    // Scale theo kich thuoc ruoi, bo phan ve sau dung toa do chuan.
    canvas.save();
    var scale = (flySize / 55) * _bossGrowthScale;
    if (_absorbingIntoBoss && !isBoss) {
      scale *= (1 - _absorbProgress * 0.55).clamp(0.35, 1.0);
    }
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

    if (isBoss) {
      final barTop = -36.0;
      final barWidth = 30.0;
      final healthRatio = _health / max(1, _effectiveMaxHealth);
      final barBg = Paint()..color = Colors.black.withValues(alpha: 0.35);
      final barFg = Paint()..color = const Color(0xFFEF5350);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-barWidth / 2, barTop, barWidth, 5),
          const Radius.circular(4),
        ),
        barBg,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-barWidth / 2, barTop, barWidth * healthRatio, 5),
          const Radius.circular(4),
        ),
        barFg,
      );
    }

    if (_hitFlash > 0) {
      final flashPaint =
          Paint()
            ..color = Colors.white.withValues(
              alpha: _hitFlash.clamp(0, 1) * 0.42,
            );
      canvas.drawCircle(Offset.zero, 24, flashPaint);
    }

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
    applyDamage(amount: 1, playHitSfx: true);
  }

  void applyDamage({int amount = 1, bool playHitSfx = true}) {
    if (isSwatted) return;

    // Cham la co phan hoi am thanh ngay, khong doi den luc ruoi chet.
    if (playHitSfx) {
      game._playFlyHitSfx();
    }

    _health -= max(1, amount);
    _hitFlash = 1;

    if (_health > 0) {
      game.onFlyDamaged(
        position,
        isBoss: isBoss,
        remainingHealth: _health,
        maxHealth: _effectiveMaxHealth,
      );
      return;
    }

    forceSwat(playHitSfx: false);
  }

  void forceSwat({bool playHitSfx = true}) {
    if (isSwatted) return;

    // Dap trung: cong diem + xoa sau 1 khoang ngan de hien hieu ung.
    isSwatted = true;
    velocity = Vector2.zero();
    _swatElapsed = 0;
    _prepareSplatDebris();
    if (playHitSfx) {
      game._playFlyHitSfx();
    }
    game.flySwatted(position, pointValue, wasBoss: isBoss);
  }

  void _prepareSplatDebris() {
    _splatBlobs.clear();
    _splatLines.clear();

    final blobCount = isBoss ? 12 : 8;
    for (int i = 0; i < blobCount; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final distance = 10 + random.nextDouble() * (isBoss ? 28 : 18);
      final drift =
          Offset(cos(angle), sin(angle)) * (6 + random.nextDouble() * 16);
      _splatBlobs.add(
        _SplatBlob(
          origin: Offset(cos(angle) * distance, sin(angle) * distance * 0.7),
          drift: drift,
          radius: 2.4 + random.nextDouble() * (isBoss ? 3.8 : 2.2),
        ),
      );
    }

    for (int i = 0; i < 6; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final base = Offset(cos(angle) * 10, sin(angle) * 6);
      final tip = base + Offset(cos(angle) * 8, sin(angle) * 8);
      final drift = Offset(cos(angle) * 12, sin(angle) * 10);
      _splatLines.add(_SplatLine(start: base, end: tip, drift: drift));
    }
  }

  void startExitFlight() {
    if (isSwatted || _exiting || _absorbingIntoBoss) return;
    _exiting = true;

    // Ruoi thuong bay vuot bien man hinh de nhuong san cho boss.
    final target = Vector2(game.size.x / 2, game.size.y / 2);
    var away = position - target;
    if (away.length2 < 0.0001) {
      away = Vector2(1, 0);
    } else {
      away.normalize();
    }
    velocity = away * (220 + random.nextDouble() * 70);
  }

  void startAbsorbIntoBoss(Fly boss) {
    if (isBoss || isSwatted || boss.isSwatted || boss.parent == null) return;

    if (_absorbingIntoBoss && identical(_absorbTargetBoss, boss)) {
      return;
    }

    _collisionLocked = false;
    _exiting = false;
    _absorbingIntoBoss = true;
    _absorbTargetBoss = boss;
    _absorbProgress = 0;
    _reproduceCooldown = 99;
  }

  void _updateAbsorbIntoBoss(double dt) {
    final boss = _absorbTargetBoss;
    if (boss == null || boss.parent == null || boss.isSwatted) {
      _absorbingIntoBoss = false;
      _absorbTargetBoss = null;
      _absorbProgress = 0;
      _changeDirection();
      return;
    }

    var toBoss = boss.position - position;
    if (toBoss.length2 < 0.0001) {
      toBoss = Vector2(1, 0);
    }
    final distance = toBoss.length;
    toBoss.normalize();

    final absorbSpeed = (190 + flySize * 1.7) * (isMutant ? 1.08 : 1.0);
    velocity = toBoss * absorbSpeed;
    position += velocity * dt;
    animationTime += dt * 20;
    wingAngle = sin(animationTime) * 0.28;
    _absorbProgress = min(1, _absorbProgress + dt * 2.7);

    final mergeRadius = boss.flySize * boss._bossGrowthScale * 0.35 + 10;
    if (distance <= mergeRadius) {
      game.onFlyMergedIntoBoss(boss: boss, absorbedFly: this);
      removeFromParent();
    }
  }

  void absorbFlyPower({required int healthGain, required int damageGain}) {
    if (!isBoss || isSwatted) return;

    final safeHealth = max(0, healthGain);
    final safeDamage = max(0, damageGain);
    _bonusMaxHealth += safeHealth;
    _bonusDropDamage += safeDamage;
    _health += safeHealth;
    _absorbedFlyCount++;
    _empowerPulse = 1;
    _hitFlash = 0.65;
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    final hitRadius = (flySize * 0.5 * _bossGrowthScale) + 14;
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
      canReproduce &&
      !_collisionLocked &&
      !_absorbingIntoBoss &&
      _reproduceCooldown <= 0;
}

class _SplatBlob {
  final Offset origin;
  final Offset drift;
  final double radius;

  const _SplatBlob({
    required this.origin,
    required this.drift,
    required this.radius,
  });
}

class _SplatLine {
  final Offset start;
  final Offset end;
  final Offset drift;

  const _SplatLine({
    required this.start,
    required this.end,
    required this.drift,
  });
}
