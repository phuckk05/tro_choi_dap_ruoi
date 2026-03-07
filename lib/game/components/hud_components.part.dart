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
      comboText.text = 'x$combo🔥';
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

class DifficultyNotice extends PositionComponent {
  late final TextComponent _noticeText;
  double _remaining = 0;
  bool _visible = false;
  static final Vector2 _panelSize = Vector2(320, 78);
  static const double _showDuration = 2.2;
  static final Paint _shadowPaint = Paint()..color = const Color(0x77000000);
  static final Paint _panelPaint = Paint()..color = const Color(0xFFF57C00);
  static final Paint _borderPaint =
      Paint()
        ..color = const Color(0xFFFFF3E0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;

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
          color: Color(0xFFFFF8E1),
          fontSize: 28,
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

  void show(String message) {
    // Hien banner trong mot khoang ngan moi khi len cap do kho.
    _noticeText.text = message;
    _remaining = _showDuration;
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

    // Card thong bao co gradient + shadow de doc tren moi background.
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final card = RRect.fromRectAndRadius(rect, const Radius.circular(22));
    canvas.drawRRect(card.shift(const Offset(0, 4)), _shadowPaint);

    _panelPaint.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(size.x, size.y),
      const [Color(0xFFF57C00), Color(0xFFE65100)],
    );
    canvas.drawRRect(card, _panelPaint);
    canvas.drawRRect(card, _borderPaint);

    super.render(canvas);
  }
}
