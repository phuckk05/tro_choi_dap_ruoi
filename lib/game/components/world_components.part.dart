part of '../fly_swatter_game.dart';

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
          [const Color(0xFFFFE082), const Color(0xFFF57F17)],
        )
        ..style = PaintingStyle.fill;
  static final Paint _soupEdgePaint =
      Paint()
        ..color = const Color(0xFFFFB300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
  static final Paint _noodleOutlinePaint =
      Paint()
        ..color = const Color(0xFFE6A817)
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
  static final Paint _noodlePaint =
      Paint()
        ..color = const Color(0xFFFFF59D)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
  static final Paint _steamPaint =
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
  double _steamTime = 0;
  double _contaminationPercent = 0;
  bool _shieldActive = false;
  int _shieldCurrentHits = 0;
  int _shieldMaxHits = 10;
  late TextPainter _percentPainter;
  late TextPainter _shieldHitsPainter;

  NoodleBowl({required super.position})
    : super(size: Vector2(190, 80), anchor: Anchor.topLeft, priority: -3) {
    _percentPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    _shieldHitsPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
  }

  void setContaminationProgress(double percent) {
    // 100% la sach hoan toan, 0% la thua game.
    _contaminationPercent = percent.clamp(0, 100);
  }

  void setShieldState({
    required bool active,
    required int currentHits,
    required int maxHits,
  }) {
    _shieldActive = active;
    _shieldCurrentHits = max(0, currentHits);
    _shieldMaxHits = max(1, maxHits);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _steamTime += dt;
  }

  bool containsWorldPoint(Vector2 worldPoint) {
    // Hitbox theo mien hinh oval phan mat to mi.
    final local = (worldPoint - position) - Vector2(size.x / 2, size.y);
    const bowlTop = -70.0;
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

    // Steam duoc animate bang sin theo thoi gian.
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
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -2), width: 132, height: 23),
      _soupEdgePaint,
    );

    if (_shieldActive) {
      final shieldPulse =
          (0.24 + sin(_steamTime * 7.5 + _shieldCurrentHits * 1.8) * 0.07)
              .clamp(0.16, 0.34)
              .toDouble();
      final shieldPaint =
          Paint()
            ..color = const Color(0xFF29B6F6).withValues(alpha: shieldPulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3;
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -2), width: 150, height: 42),
        shieldPaint,
      );

      // Nap noi dong kin phan mat to trong suot thoi gian bao ve.
      final lidPaint =
          Paint()
            ..shader = ui.Gradient.linear(
              const Offset(0, -26),
              const Offset(0, 8),
              [const Color(0xFFF3F6F8), const Color(0xFF90A4AE)],
            )
            ..style = PaintingStyle.fill;
      final lidBorder =
          Paint()
            ..color = const Color(0xFF546E7A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8;
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -4), width: 136, height: 30),
        lidPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -4), width: 136, height: 30),
        lidBorder,
      );

      // Thanh do ben khiên hien ngay tren nap.
      final barWidth = 74.0;
      const barHeight = 7.0;
      final barLeft = -barWidth / 2;
      const barTop = -9.5;
      final barRect = Rect.fromLTWH(barLeft, barTop, barWidth, barHeight);
      final barBg = Paint()..color = const Color(0xAA102027);
      final barBorder =
          Paint()
            ..color = const Color(0xCCFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(5)),
        barBg,
      );

      final shieldRatio =
          (_shieldCurrentHits / _shieldMaxHits).clamp(0, 1).toDouble();
      if (shieldRatio > 0) {
        final fillRect = Rect.fromLTWH(
          barRect.left + 1,
          barRect.top + 1,
          (barRect.width - 2) * shieldRatio,
          barRect.height - 2,
        );
        final fillPaint =
            Paint()
              ..shader = ui.Gradient.linear(
                fillRect.topLeft,
                fillRect.topRight,
                const [Color(0xFF80DEEA), Color(0xFF00ACC1)],
              );
        canvas.drawRRect(
          RRect.fromRectAndRadius(fillRect, const Radius.circular(4)),
          fillPaint,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(5)),
        barBorder,
      );

      _shieldHitsPainter.text = TextSpan(
        text: '$_shieldCurrentHits/$_shieldMaxHits',
        style: const TextStyle(
          color: Color(0xFFE0F7FA),
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(
              color: Color(0xCC000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
      );
      _shieldHitsPainter.layout();
      _shieldHitsPainter.paint(
        canvas,
        Offset(-_shieldHitsPainter.width / 2, barTop - 9.5),
      );

      final lidGloss =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.34)
            ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -10), width: 92, height: 10),
        lidGloss,
      );

      final knobPaint = Paint()..color = const Color(0xFF455A64);
      final knobBasePaint = Paint()..color = const Color(0xFF78909C);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -21), width: 26, height: 8),
        knobBasePaint,
      );
      canvas.drawCircle(const Offset(0, -25), 6, knobPaint);
    }

    for (int i = -3; i <= 3; i++) {
      final baseX = i * 17.0;
      final path =
          Path()
            ..moveTo(baseX - 12, -2)
            ..quadraticBezierTo(baseX - 5, -8, baseX + 2, -2)
            ..quadraticBezierTo(baseX + 9, 4, baseX + 14, -1);
      canvas.drawPath(path, _noodleOutlinePaint);
      canvas.drawPath(path, _noodlePaint);
    }

    // Hien % do sach de nguoi choi theo doi dieu kien thua.
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
    final percentBg =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.62)
          ..style = PaintingStyle.fill;
    final percentRect = Rect.fromLTWH(
      -_percentPainter.width / 2 - 6,
      36,
      _percentPainter.width + 12,
      _percentPainter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(percentRect, const Radius.circular(7)),
      percentBg,
    );
    _percentPainter.paint(canvas, Offset(-_percentPainter.width / 2, 38));

    canvas.restore();
  }
}

class FlyDropping extends PositionComponent {
  final FlySwatterGame game;
  Vector2 velocity;
  final int contaminationDamage;

  static final Paint _dropPaint =
      Paint()
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.fill;

  FlyDropping({
    required super.position,
    required this.game,
    Vector2? initialVelocity,
    this.contaminationDamage = 1,
  }) : velocity = initialVelocity?.clone() ?? Vector2(0, 30),
       super(size: Vector2.all(6), anchor: Anchor.center, priority: 1);

  @override
  void update(double dt) {
    super.update(dt);

    velocity.y += 520 * dt;
    position += velocity * dt;

    // Roi vao to mi thi cap nhat muc do nhiem ban va xoa drop.
    if (game.isPointInsideNoodleBowl(position)) {
      removeFromParent();
      game.onNoodleBowlContaminated(damageUnits: contaminationDamage);
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

    // Hieu ung hat bay roi bien mat dan theo life.
    _paint.color = color.withValues(alpha: life.clamp(0, 1));

    if (life <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset.zero, size.x / 2, _paint);
  }
}

class FloatingRewardText extends PositionComponent {
  final String text;
  final Color color;
  final double lifetime;
  final double riseSpeed;
  double _remaining;
  late final TextPainter _painter;

  FloatingRewardText({
    required super.position,
    required this.text,
    required this.color,
    this.lifetime = 0.65,
    this.riseSpeed = 26,
  }) : _remaining = lifetime,
       super(anchor: Anchor.center, priority: 7);

  @override
  Future<void> onLoad() async {
    _painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _remaining -= dt;
    position += Vector2(0, -riseSpeed * dt);
    if (_remaining <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final alpha = (_remaining / lifetime).clamp(0, 1).toDouble();
    _painter.text = TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: alpha),
        fontSize: 18,
        fontWeight: FontWeight.w900,
        shadows: const [
          Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
    );
    _painter.layout();
    _painter.paint(canvas, Offset(-_painter.width / 2, -_painter.height / 2));
  }
}

class ShieldBlockEffect extends PositionComponent {
  double _remaining = 0.22;
  static final Paint _ringPaint =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

  ShieldBlockEffect({required super.position})
    : super(size: Vector2.all(16), anchor: Anchor.center, priority: 7);

  @override
  void update(double dt) {
    super.update(dt);
    _remaining -= dt;
    size += Vector2.all(150 * dt);
    if (_remaining <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_remaining / 0.22).clamp(0, 1);
    _ringPaint.color = const Color(0xFF4FC3F7).withValues(alpha: t * 0.8);
    canvas.drawCircle(Offset.zero, size.x / 2, _ringPaint);
  }
}
