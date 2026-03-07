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
    // 100% la sach hoan toan, 0% la thua game.
    _contaminationPercent = percent.clamp(0, 100);
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

    for (int i = -3; i <= 3; i++) {
      final baseX = i * 17.0;
      final path =
          Path()
            ..moveTo(baseX - 12, -2)
            ..quadraticBezierTo(baseX - 5, -8, baseX + 2, -2)
            ..quadraticBezierTo(baseX + 9, 4, baseX + 14, -1);
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
    _percentPainter.paint(canvas, Offset(-_percentPainter.width / 2, 38));

    canvas.restore();
  }
}

class FlyDropping extends PositionComponent {
  final FlySwatterGame game;
  Vector2 velocity;

  static final Paint _dropPaint =
      Paint()
        ..color = const Color(0xFF5D4037)
        ..style = PaintingStyle.fill;

  FlyDropping({
    required super.position,
    required this.game,
    Vector2? initialVelocity,
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
