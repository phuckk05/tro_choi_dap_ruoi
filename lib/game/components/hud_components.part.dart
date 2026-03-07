part of '../fly_swatter_game.dart';

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
    // 3 style mau cho moc thoi gian binh thuong/canh bao/nguy cap.
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
    _cardShadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.12);
    _cardFillPaint =
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, 0), Offset(0, size.y), [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.86),
          ]);
    _cardBorderPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
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
    // Ve the nen HUD truoc, sau do render cac TextComponent con.
    canvas.drawRRect(_cardRRect.shift(const Offset(0, 2)), _cardShadowPaint);
    canvas.drawRRect(_cardRRect, _cardFillPaint);
    canvas.drawRRect(_cardRRect, _cardBorderPaint);

    super.render(canvas);
  }

  void updateScore(int score, int combo, int highScore) {
    scoreText.text = '🏆 $score';

    // Chi hien combo khi >= 2 de tranh roi mat.
    if (combo > 1) {
      comboText.text = 'x$combo';
    } else {
      comboText.text = '';
    }
  }

  void updateTime(int seconds) {
    if (seconds == _lastShownTime) return;
    _lastShownTime = seconds;
    timeText.text = '⏱️ $seconds';

    // Chuyen mau theo nguong thoi gian de tao cam giac ap luc tang dan.
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

class ShieldEnergyBar extends PositionComponent {
  double _remaining = 0;
  double _maxDuration = 5;
  bool _active = false;

  ShieldEnergyBar({required super.position})
    : super(size: Vector2(140, 16), anchor: Anchor.topLeft, priority: 2);

  void setShield({required double remaining, required double maxDuration}) {
    _remaining = remaining.clamp(0, 999);
    _maxDuration = max(0.1, maxDuration);
    _active = _remaining > 0;
  }

  @override
  void render(Canvas canvas) {
    if (!_active) return;

    final baseRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final card = RRect.fromRectAndRadius(baseRect, const Radius.circular(9));

    final bgPaint = Paint()..color = const Color(0xAA102027);
    final borderPaint =
        Paint()
          ..color = const Color(0xB0FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1;
    canvas.drawRRect(card, bgPaint);

    final ratio = (_remaining / _maxDuration).clamp(0, 1).toDouble();
    if (ratio > 0) {
      final fillRect = Rect.fromLTWH(
        1.5,
        1.5,
        (size.x - 3) * ratio,
        size.y - 3,
      );
      final fillRRect = RRect.fromRectAndRadius(
        fillRect,
        const Radius.circular(7),
      );

      final fillPaint =
          Paint()
            ..shader = ui.Gradient.linear(
              fillRect.topLeft,
              fillRect.topRight,
              const [Color(0xFF80DEEA), Color(0xFF00ACC1)],
            );
      canvas.drawRRect(fillRRect, fillPaint);

      final shinePaint =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.24)
            ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            fillRect.left,
            fillRect.top,
            fillRect.width,
            fillRect.height * 0.45,
          ),
          const Radius.circular(7),
        ),
        shinePaint,
      );
    }

    canvas.drawRRect(card, borderPaint);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: 'Lá chắn ${_remaining.toStringAsFixed(1)}s',
        style: const TextStyle(
          color: Color(0xFFE0F7FA),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(
              color: Color(0xCC000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    )..layout(maxWidth: size.x - 8);
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        (size.y - textPainter.height) / 2,
      ),
    );
  }
}

class SlapEnergyBar extends PositionComponent {
  double _remaining = 0;
  double _maxDuration = 5;
  bool _active = false;

  SlapEnergyBar({required super.position})
    : super(size: Vector2(140, 16), anchor: Anchor.topLeft, priority: 2);

  void setSlap({required double remaining, required double maxDuration}) {
    _remaining = remaining.clamp(0, 999);
    _maxDuration = max(0.1, maxDuration);
    _active = _remaining > 0;
  }

  @override
  void render(Canvas canvas) {
    if (!_active) return;

    final baseRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final card = RRect.fromRectAndRadius(baseRect, const Radius.circular(9));

    final bgPaint = Paint()..color = const Color(0xAA102027);
    final borderPaint =
        Paint()
          ..color = const Color(0xB0FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1;
    canvas.drawRRect(card, bgPaint);

    final ratio = (_remaining / _maxDuration).clamp(0, 1).toDouble();
    if (ratio > 0) {
      final fillRect = Rect.fromLTWH(
        1.5,
        1.5,
        (size.x - 3) * ratio,
        size.y - 3,
      );
      final fillRRect = RRect.fromRectAndRadius(
        fillRect,
        const Radius.circular(7),
      );

      final fillPaint =
          Paint()
            ..shader = ui.Gradient.linear(
              fillRect.topLeft,
              fillRect.topRight,
              const [Color(0xFFFFCC80), Color(0xFFEF6C00)],
            );
      canvas.drawRRect(fillRRect, fillPaint);

      final shinePaint =
          Paint()
            ..color = Colors.white.withValues(alpha: 0.22)
            ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            fillRect.left,
            fillRect.top,
            fillRect.width,
            fillRect.height * 0.45,
          ),
          const Radius.circular(7),
        ),
        shinePaint,
      );
    }

    canvas.drawRRect(card, borderPaint);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: 'Vợt ${_remaining.toStringAsFixed(1)}s',
        style: const TextStyle(
          color: Color(0xFFFFF3E0),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(
              color: Color(0xCC000000),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    )..layout(maxWidth: size.x - 8);
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        (size.y - textPainter.height) / 2,
      ),
    );
  }
}

class DifficultyNotice extends PositionComponent {
  late final TextComponent _noticeText;
  double _remaining = 0;
  bool _visible = false;
  static final Vector2 _panelSize = Vector2(320, 78);
  static const double _showDuration = 1.8;

  DifficultyNotice()
    : super(size: _panelSize, anchor: Anchor.center, priority: 5);

  @override
  Future<void> onLoad() async {
    _noticeText = TextComponent(
      text: '',
      position: _panelSize / 2,
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFDF7E8),
          fontSize: 25,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
          shadows: [
            Shadow(
              color: Color(0xB3000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
    add(_noticeText);
  }

  void show(String message, {double duration = _showDuration}) {
    // Hien banner trong mot khoang ngan moi khi len cap do kho.
    _noticeText.text = message;
    _remaining = duration;
    _visible = true;
  }

  void setPanelWidth(double width) {
    size = Vector2(width, _panelSize.y);
    _noticeText.position = size / 2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_remaining <= 0) return;

    _remaining -= dt;
    if (_remaining <= 0) {
      _visible = false;
      _noticeText.text = '';
    }
  }

  @override
  void render(Canvas canvas) {
    if (!_visible || _noticeText.text.isEmpty) return;

    super.render(canvas);
  }
}

class ScreenFlashEffect extends PositionComponent {
  final Vector2 screenSize;
  final double duration;
  double _remaining;
  static final Paint _flashPaint = Paint()..style = PaintingStyle.fill;

  ScreenFlashEffect({required this.screenSize, this.duration = 0.18})
    : _remaining = duration,
      super(size: screenSize, position: Vector2.zero(), priority: 6);

  @override
  void update(double dt) {
    super.update(dt);
    _remaining -= dt;
    if (_remaining <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_remaining / duration).clamp(0, 1);
    _flashPaint.color = const Color(0xFFFFF3E0).withValues(alpha: t * 0.1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _flashPaint);
  }
}
