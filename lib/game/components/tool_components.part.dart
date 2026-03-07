part of '../fly_swatter_game.dart';

final Map<String, ui.Image> _toolImageCache = <String, ui.Image>{};

Future<ui.Image> _loadUiImageAsset(String assetPath) async {
  final cached = _toolImageCache[assetPath];
  if (cached != null) return cached;

  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  final image = frame.image;
  _toolImageCache[assetPath] = image;
  return image;
}

class ToolRack extends PositionComponent with TapCallbacks {
  final void Function(ToolType type)? onToolTap;

  static const List<ToolType> _slotOrder = [
    ToolType.shield,
    ToolType.slap,
    ToolType.strikeSet,
  ];

  final Map<ToolType, int> _counts = {
    ToolType.shield: 0,
    ToolType.slap: 0,
    ToolType.strikeSet: 0,
  };
  final Map<ToolType, ui.Image> _icons = <ToolType, ui.Image>{};
  final Map<ToolType, double> _tapFeedback = {
    ToolType.shield: 0,
    ToolType.slap: 0,
    ToolType.strikeSet: 0,
  };
  late final TextPainter _countPainter;

  ToolRack({this.onToolTap})
    : super(size: Vector2(44, 104), anchor: Anchor.bottomRight, priority: 8) {
    _countPainter = TextPainter(textDirection: TextDirection.ltr);
  }

  @override
  Future<void> onLoad() async {
    await _ensureToolImagesLoaded();
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final type in _slotOrder) {
      final value = _tapFeedback[type] ?? 0;
      if (value > 0) {
        _tapFeedback[type] = max(0, value - dt * 2.8);
      } else if (value < 0) {
        _tapFeedback[type] = min(0, value + dt * 3.4);
      }
    }
  }

  void setCount(ToolType type, int value) {
    _counts[type] = value < 0 ? 0 : value;
  }

  Vector2 getSlotWorldCenter(ToolType type) {
    final slot = _slotRect(_slotOrder.indexOf(type));
    final topLeft = Vector2(position.x - size.x, position.y - size.y);
    return topLeft + Vector2(slot.center.dx, slot.center.dy);
  }

  Rect _slotRect(int index) {
    const left = 0.0;
    const topStart = 0.0;
    const slotHeight = 34.0;
    const gap = 1.0;
    return Rect.fromLTWH(
      left,
      topStart + index * (slotHeight + gap),
      size.x,
      slotHeight,
    );
  }

  Future<void> _ensureToolImagesLoaded() async {
    final entries = <ToolType, String>{
      ToolType.shield: _toolAssetPath(ToolType.shield),
      ToolType.slap: _toolAssetPath(ToolType.slap),
      ToolType.strikeSet: _toolAssetPath(ToolType.strikeSet),
    };

    for (final entry in entries.entries) {
      try {
        _icons[entry.key] = await _loadUiImageAsset(entry.value);
      } catch (_) {
        // Neu thieu asset se fallback ve icon vector don gian.
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    final local = event.localPosition;
    final point = Offset(local.x, local.y);
    for (int i = 0; i < _slotOrder.length; i++) {
      final rect = _slotRect(i);
      if (rect.contains(point)) {
        final type = _slotOrder[i];
        final count = _counts[type] ?? 0;
        _tapFeedback[type] = count > 0 ? 1.0 : -1.0;
        if (count > 0) {
          onToolTap?.call(type);
        }
        return;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    for (int i = 0; i < _slotOrder.length; i++) {
      final type = _slotOrder[i];
      final rect = _slotRect(i);
      final feedback = _tapFeedback[type] ?? 0;

      final slotCard = RRect.fromRectAndRadius(
        rect.deflate(1),
        const Radius.circular(10),
      );
      final slotPaint =
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(rect.left, rect.top),
              Offset(rect.left, rect.bottom),
              const [Color(0xCCF7FAFC), Color(0xCCC7D0D7)],
            );
      canvas.drawRRect(slotCard, slotPaint);

      final slotBorder =
          Paint()
            ..color = const Color(0xFF90A4AE).withValues(alpha: 0.72)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1;
      canvas.drawRRect(slotCard, slotBorder);

      if (feedback > 0) {
        final pulsePaint =
            Paint()
              ..color = const Color(
                0xFF00BCD4,
              ).withValues(alpha: feedback * 0.26)
              ..style = PaintingStyle.fill;
        canvas.drawRRect(slotCard.inflate(1), pulsePaint);
      } else if (feedback < 0) {
        final warnPaint =
            Paint()
              ..color = const Color(
                0xFFD32F2F,
              ).withValues(alpha: (-feedback) * 0.28)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2;
        canvas.drawRRect(slotCard, warnPaint);
      }

      final imageRect = Rect.fromCenter(
        center: Offset(rect.center.dx, rect.center.dy),
        width: 32,
        height: 32,
      );
      final icon = _icons[type];
      if (icon != null) {
        canvas.drawImageRect(
          icon,
          Rect.fromLTWH(0, 0, icon.width.toDouble(), icon.height.toDouble()),
          imageRect,
          Paint()..filterQuality = FilterQuality.high,
        );
      } else {
        final fallbackBg =
            Paint()..color = _toolColor(type).withValues(alpha: 0.86);
        canvas.drawCircle(imageRect.center, 10, fallbackBg);
      }

      final count = _counts[type] ?? 0;
      _countPainter.text = TextSpan(
        text: '$count',
        style: TextStyle(
          color: count > 0 ? const Color(0xFFFFF59D) : const Color(0xFFCFD8DC),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(
              color: Color(0xCC000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
      );
      _countPainter.layout();
      _countPainter.paint(
        canvas,
        Offset(
          imageRect.right - _countPainter.width - 1,
          imageRect.bottom - _countPainter.height,
        ),
      );
    }
  }
}

class ToolPickupFlyToRack extends PositionComponent {
  final ToolType type;
  final Vector2 startPosition;
  final Vector2 Function() targetPositionProvider;
  final double holdDuration;
  final VoidCallback onArrive;

  bool _flying = false;
  bool _arrived = false;
  double _holdRemaining;
  double _flightElapsed = 0;
  late Vector2 _flightStart;
  late Vector2 _flightTarget;
  ui.Image? _icon;

  ToolPickupFlyToRack({
    required this.type,
    required this.startPosition,
    required this.targetPositionProvider,
    required this.holdDuration,
    required this.onArrive,
  }) : _holdRemaining = holdDuration,
       super(
         position: startPosition.clone(),
         size: Vector2.all(26),
         anchor: Anchor.center,
         priority: 9,
       );

  @override
  Future<void> onLoad() async {
    try {
      _icon = await _loadUiImageAsset(_toolAssetPath(type));
    } catch (_) {}
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!_flying) {
      _holdRemaining -= dt;
      if (_holdRemaining <= 0) {
        _flying = true;
        _flightStart = position.clone();
        _flightTarget = targetPositionProvider();
      }
      return;
    }

    _flightElapsed += dt;
    final t = (_flightElapsed / 0.55).clamp(0, 1).toDouble();
    final curved = Curves.easeInOutCubic.transform(t);
    position = _flightStart + (_flightTarget - _flightStart) * curved;

    if (t >= 1 && !_arrived) {
      _arrived = true;
      onArrive();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final pulse =
        _flying ? 1.0 : (1 + sin((holdDuration - _holdRemaining) * 8) * 0.08);
    final alpha = _flying ? 0.95 : 1.0;
    final bg = Paint()..color = _toolColor(type).withValues(alpha: alpha);
    final glow = Paint()..color = Colors.white.withValues(alpha: 0.26 * alpha);

    canvas.save();
    canvas.scale(pulse, pulse);
    canvas.drawCircle(Offset.zero, 12, bg);
    canvas.drawCircle(Offset.zero, 6, glow);
    final icon = _icon;
    if (icon != null) {
      canvas.drawImageRect(
        icon,
        Rect.fromLTWH(0, 0, icon.width.toDouble(), icon.height.toDouble()),
        Rect.fromCenter(center: Offset.zero, width: 12, height: 12),
        Paint()..filterQuality = FilterQuality.high,
      );
    }
    canvas.restore();
  }
}

class SwatNetOverlay extends PositionComponent with DragCallbacks {
  final ValueChanged<Vector2> onSwatAt;
  final VoidCallback onFinished;
  double _remaining;
  bool _inputEnabled = true;
  bool _finished = false;
  Vector2? _cursor;
  final List<Vector2> _trail = <Vector2>[];

  SwatNetOverlay({
    required Vector2 screenSize,
    required this.onSwatAt,
    required this.onFinished,
    double duration = 5.0,
  }) : _remaining = duration,
       super(
         size: screenSize,
         position: Vector2.zero(),
         anchor: Anchor.topLeft,
         // Dat thap hon HUD/tool de khong che mat va khong chan thao tac.
         priority: 0,
       );

  void setScreenSize(Vector2 size) {
    this.size = size.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _remaining -= dt;
    if (_remaining <= 0) {
      _remaining = 0;
      _inputEnabled = false;
      if (_finished) return;
      _finished = true;
      onFinished();
      removeFromParent();
      return;
    }

    if (_trail.length > 12) {
      _trail.removeAt(0);
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_inputEnabled || _remaining <= 0) return;
    final p = event.canvasEndPosition;
    _cursor = p;
    _trail.add(p.clone());
    onSwatAt(p);
  }

  @override
  void render(Canvas canvas) {
    final overlayPaint =
        Paint()
          ..color = const Color(0xFF102027).withValues(alpha: 0.12)
          ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), overlayPaint);

    final cursor = _cursor;
    if (cursor == null) return;

    final center = Offset(cursor.x, cursor.y);
    double angle = pi / 5;
    if (_trail.length >= 2) {
      final p1 = _trail[_trail.length - 2];
      final p2 = _trail[_trail.length - 1];
      angle = atan2(p2.y - p1.y, p2.x - p1.x) + pi / 9;
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final handleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(15, -4.5, 64, 9),
      const Radius.circular(5),
    );
    final handlePaint =
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(15, 0),
            const Offset(79, 0),
            const [Color(0xFF8D6E63), Color(0xFF4E342E)],
          );
    canvas.drawRRect(handleRect, handlePaint);

    final neckPaint = Paint()..color = const Color(0xFF90A4AE);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, 0), width: 12, height: 8),
      neckPaint,
    );

    final frameRect = Rect.fromCenter(
      center: Offset.zero,
      width: 48,
      height: 38,
    );
    final frameOuter =
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(-24, -18),
            const Offset(24, 18),
            const [Color(0xFFF5F5F5), Color(0xFF90A4AE)],
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
    canvas.drawOval(frameRect, frameOuter);

    final innerRect = frameRect.deflate(4);
    final meshStroke =
        Paint()
          ..color = const Color(0xFFCFD8DC)
          ..strokeWidth = 0.9;
    canvas.save();
    final clip = Path()..addOval(innerRect);
    canvas.clipPath(clip);
    for (double x = innerRect.left; x <= innerRect.right; x += 4) {
      canvas.drawLine(
        Offset(x, innerRect.top),
        Offset(x, innerRect.bottom),
        meshStroke,
      );
    }
    for (double y = innerRect.top; y <= innerRect.bottom; y += 4) {
      canvas.drawLine(
        Offset(innerRect.left, y),
        Offset(innerRect.right, y),
        meshStroke,
      );
    }
    canvas.restore();

    final highlightPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
    canvas.drawArc(frameRect, -2.6, 1.4, false, highlightPaint);

    canvas.restore();
  }
}

class LightningStormEffect extends PositionComponent {
  final List<Vector2> strikeTargets;
  final VoidCallback onCompleted;
  double _remaining = 0.62;
  bool _fired = false;
  final List<_LightningBolt> _bolts = <_LightningBolt>[];

  LightningStormEffect({
    required Vector2 screenSize,
    required this.strikeTargets,
    required this.onCompleted,
  }) : super(
         size: screenSize,
         position: Vector2.zero(),
         anchor: Anchor.topLeft,
         priority: 12,
       );

  @override
  void update(double dt) {
    super.update(dt);
    if (!_fired) {
      _fired = true;
      onCompleted();
    }
    _remaining -= dt;
    if (_remaining <= 0) {
      removeFromParent();
    }
  }

  void _ensureBolts() {
    if (_bolts.isNotEmpty) return;
    for (int i = 0; i < strikeTargets.length; i++) {
      _bolts.add(_buildBolt(strikeTargets[i], i));
    }
  }

  _LightningBolt _buildBolt(Vector2 target, int index) {
    final rng = Random(target.x.toInt() ^ (target.y.toInt() << 3) ^ index);
    final startX = (target.x + (rng.nextDouble() - 0.5) * 110).clamp(
      16,
      size.x - 16,
    );
    final start = Offset(startX.toDouble(), -24);

    final points = <Offset>[start];
    const segmentCount = 7;
    for (int i = 1; i <= segmentCount; i++) {
      final ty = target.y * (i / segmentCount);
      final jitter =
          (rng.nextDouble() - 0.5) * 56 * (1 - (i / segmentCount) * 0.35);
      final px = (target.x + jitter).clamp(8, size.x - 8).toDouble();
      points.add(Offset(px, ty));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    final branches = <Path>[];
    for (int i = 2; i < points.length - 1; i++) {
      if (rng.nextDouble() > 0.45) continue;
      final origin = points[i];
      final branchLen = 24 + rng.nextDouble() * 36;
      final branchAngle =
          (rng.nextBool() ? -1 : 1) * (0.45 + rng.nextDouble() * 0.55);
      final p2 = Offset(
        (origin.dx + cos(branchAngle) * branchLen).clamp(6, size.x - 6),
        (origin.dy + sin(branchAngle).abs() * branchLen * 0.8).clamp(0, size.y),
      );
      final p3 = Offset(
        (p2.dx + (rng.nextDouble() - 0.5) * 18).clamp(6, size.x - 6),
        (p2.dy + 14 + rng.nextDouble() * 22).clamp(0, size.y),
      );
      final branch =
          Path()
            ..moveTo(origin.dx, origin.dy)
            ..lineTo(p2.dx, p2.dy)
            ..lineTo(p3.dx, p3.dy);
      branches.add(branch);
    }

    return _LightningBolt(main: path, branches: branches);
  }

  @override
  void render(Canvas canvas) {
    _ensureBolts();

    final progress = (1 - (_remaining / 0.62)).clamp(0, 1).toDouble();
    final flashA = max(0.0, 1 - ((progress - 0.08).abs() * 14));
    final flashB = max(0.0, 1 - ((progress - 0.28).abs() * 12));
    final flashC = max(0.0, 1 - ((progress - 0.46).abs() * 10));
    final combinedFlash = (flashA * 0.85) + (flashB * 0.65) + (flashC * 0.45);

    final darknessPulse = 0.12 + (sin(progress * 34) * 0.04 + 0.06);
    final darkPaint =
        Paint()
          ..color = Colors.black.withValues(
            alpha: darknessPulse.clamp(0.08, 0.26),
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), darkPaint);

    if (combinedFlash > 0.01) {
      final flashPaint =
          Paint()
            ..color = const Color(
              0xFFE3F2FD,
            ).withValues(alpha: combinedFlash.clamp(0, 1) * 0.28);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), flashPaint);
    }

    final glowPaint =
        Paint()
          ..color = const Color(
            0xFFBBDEFB,
          ).withValues(alpha: (0.5 + combinedFlash * 0.5).clamp(0.35, 0.9))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final corePaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.96)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
    final branchPaint =
        Paint()
          ..color = const Color(0xFFD6ECFF).withValues(alpha: 0.82)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;

    for (final bolt in _bolts) {
      canvas.drawPath(bolt.main, glowPaint);
      canvas.drawPath(bolt.main, corePaint);
      for (final branch in bolt.branches) {
        canvas.drawPath(branch, branchPaint);
      }
    }
  }
}

class _LightningBolt {
  final Path main;
  final List<Path> branches;

  _LightningBolt({required this.main, required this.branches});
}

Color _toolColor(ToolType type) {
  switch (type) {
    case ToolType.shield:
      return const Color(0xFF42A5F5);
    case ToolType.slap:
      return const Color(0xFFFF7043);
    case ToolType.strikeSet:
      return const Color(0xFFAB47BC);
  }
}

String _toolAssetPath(ToolType type) {
  switch (type) {
    case ToolType.shield:
      return 'assets/images/khien.png';
    case ToolType.slap:
      return 'assets/images/vot.png';
    case ToolType.strikeSet:
      return 'assets/images/tiaset.png';
  }
}
