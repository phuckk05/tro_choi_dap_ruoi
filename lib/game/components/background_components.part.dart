part of '../fly_swatter_game.dart';

// Dam may don gian, troi ngang man hinh va lap lai khi di het khung hinh.
class Cloud extends PositionComponent {
  static final Paint _cloudPaint =
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;

  final Random random = Random();
  late double speed;

  Cloud({required super.position})
    : super(size: Vector2(80 + Random().nextDouble() * 40, 40), priority: -10);

  @override
  Future<void> onLoad() async {
    // Toc do moi dam may duoc random de tao cam giac tu nhien.
    speed = 10 + random.nextDouble() * 20;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += speed * dt;

    final game = parent as FlySwatterGame;
    // Khi may ra khoi ben phai, dua no ve ben trai va random lai do cao.
    if (position.x > game.size.x + size.x) {
      position.x = -size.x;
      position.y = random.nextDouble() * game.size.y * 0.4;
    }
  }

  @override
  void render(Canvas canvas) {
    // Ve may bang nhieu hinh tron chong len nhau.
    canvas.drawCircle(const Offset(20, 0), 20, _cloudPaint);
    canvas.drawCircle(const Offset(40, -5), 25, _cloudPaint);
    canvas.drawCircle(const Offset(60, 0), 22, _cloudPaint);
    canvas.drawCircle(const Offset(50, 10), 18, _cloudPaint);
    canvas.drawCircle(const Offset(30, 8), 18, _cloudPaint);
  }
}

// Lop co nen o day man hinh, gom gradient va cac ngon co ve san de toi uu render.
class Grass extends PositionComponent {
  late Paint _grassPaint;
  late final List<Path> _bladePaths;
  late final List<Paint> _bladePaints;

  Grass({required super.position}) : super(priority: -5);

  @override
  Future<void> onLoad() async {
    final game = parent as FlySwatterGame;
    size = Vector2(game.size.x, 80);

    // Nen co dang gradient tu dam sang nhat theo chieu doc.
    _grassPaint =
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, 0), Offset(0, size.y), [
            const Color(0xFF4CAF50),
            const Color(0xFF66BB6A),
          ]);

    _bladePaths = <Path>[];
    _bladePaints = <Paint>[];

    // Seed co dinh giup hinh dang co on dinh qua moi lan chay game.
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
            // Duong cong quadratic tao ngon co cong nhe.
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
    // Ve lop nen co truoc, sau do ve tung ngon co len tren.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _grassPaint);

    for (int i = 0; i < _bladePaths.length; i++) {
      canvas.drawPath(_bladePaths[i], _bladePaints[i]);
    }
  }
}

// Mat troi xoay cham voi quang sang, tia nang va nhan sang.
class Sun extends PositionComponent {
  double rotationAngle = 0;

  static final Paint _glowPaint =
      Paint()..color = Colors.orange.withValues(alpha: 0.12);
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
      Paint()..color = Colors.white.withValues(alpha: 0.4);
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
    // Xoay tu tu de tao hieu ung chuyen dong nhe.
    rotationAngle += dt * 0.5;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();

    // Vong glow ngoai cung.
    canvas.drawCircle(Offset.zero, 50, _glowPaint);

    // Xoay he toa do de ve cac tia nang quay quanh tam.
    canvas.rotate(rotationAngle);
    for (int i = 0; i < 12; i++) {
      canvas.drawLine(_rayStarts[i], _rayEnds[i], _rayPaint);
    }

    canvas.restore();

    // Ve nhan mat troi va diem highlight de tao do sau.
    canvas.drawCircle(Offset.zero, 30, _corePaint);
    canvas.drawCircle(const Offset(-8, -8), 12, _highlightPaint);
  }
}

// Bui cay trang tri bang nhieu hinh tron voi lop mau toi/sang.
class Bush extends PositionComponent {
  static final Paint _bushPaint = Paint()..color = const Color(0xFF2E7D32);
  static final Paint _darkBushPaint = Paint()..color = const Color(0xFF1B5E20);
  static final Paint _highlightPaint =
      Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.6);

  Bush({required super.position})
    : super(size: Vector2(60, 40), anchor: Anchor.bottomCenter, priority: -6);

  @override
  void render(Canvas canvas) {
    // Lop toi ve truoc de tao bong do.
    canvas.drawCircle(const Offset(10, 0), 18, _darkBushPaint);
    canvas.drawCircle(const Offset(50, -5), 20, _darkBushPaint);
    canvas.drawCircle(const Offset(30, -10), 16, _darkBushPaint);

    // Lop xanh chinh.
    canvas.drawCircle(const Offset(15, -8), 16, _bushPaint);
    canvas.drawCircle(const Offset(35, -12), 18, _bushPaint);
    canvas.drawCircle(const Offset(45, -5), 15, _bushPaint);
    canvas.drawCircle(const Offset(25, -5), 14, _bushPaint);

    // Highlight de bui cay trong bot "phang".
    canvas.drawCircle(const Offset(20, -10), 8, _highlightPaint);
    canvas.drawCircle(const Offset(38, -14), 7, _highlightPaint);
  }
}
