import 'dart:math';

import 'package:flutter/material.dart';

import '../services/internet_status_service.dart';
import '../services/player_profile_service.dart';
import '../services/score_repository.dart';

/// Màn hình chính: vào game, xem bảng xếp hạng, và animation ruồi bị đập.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swatController;
  final TextEditingController _nameController = TextEditingController();

  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _swatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    _initProfile();
  }

  Future<void> _initProfile() async {
    final profile = await PlayerProfileService.instance.ensureProfile();
    if (!mounted) return;
    setState(() {
      _nameController.text = profile.playerName;
      _loadingProfile = false;
    });
  }

  Future<void> _startGame() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên từ 2 ký tự trở lên.')),
      );
      return;
    }

    final profile = await PlayerProfileService.instance.ensureProfile();
    final isTaken = await ScoreRepository.instance.isPlayerNameTaken(
      playerName: name,
      excludingPlayerId: profile.playerId,
    );

    if (isTaken) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tên người chơi đã tồn tại, vui lòng chọn tên khác.'),
        ),
      );
      return;
    }

    await PlayerProfileService.instance.ensureProfile(preferredName: name);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/game');
  }

  @override
  void dispose() {
    _swatController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6AA9E9),
              Color(0xFF8CC7F0),
              Color(0xFFBCE6F8),
              Color(0xFFEFFBFF),
            ],
            stops: [0.0, 0.32, 0.72, 1.0],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _DepthGridPainter()),
              ),
            ),
            Positioned(
              top: -80,
              right: -70,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -90,
              bottom: 44,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -50,
              bottom: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: const Color(0xFF4FC3F7).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: Transform(
                        alignment: Alignment.center,
                        transform:
                            Matrix4.identity()
                              ..setEntry(3, 2, 0.0012)
                              ..rotateX(0.02),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.98),
                                Colors.white.withValues(alpha: 0.90),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0D47A1,
                                ).withValues(alpha: 0.16),
                                blurRadius: 36,
                                spreadRadius: 2,
                                offset: const Offset(0, 16),
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, -2),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.86),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SwatAnimation(controller: _swatController),
                              const SizedBox(height: 12),
                              const Text(
                                'ĐẬP RUỒI',
                                style: TextStyle(
                                  fontSize: 50,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1B4965),
                                  letterSpacing: 1.6,
                                  height: 1,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x553FA9F5),
                                      blurRadius: 12,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Đập ruồi thật nhanh trong 60 giây và săn điểm cao nhất!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF355C7D),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: const [
                                  _InfoChip(label: 'Nhanh tay'),
                                  _InfoChip(label: 'Chuẩn xác'),
                                  _InfoChip(label: 'Săn kỷ lục'),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _nameController,
                                enabled: !_loadingProfile,
                                maxLength: 20,
                                decoration: InputDecoration(
                                  labelText: 'Tên người chơi',
                                  counterText: '',
                                  hintText: 'Nhập tên của bạn',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      _loadingProfile ? null : _startGame,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF43A047),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 10,
                                    shadowColor: const Color(
                                      0xFF2E7D32,
                                    ).withValues(alpha: 0.5),
                                  ),
                                  child: const Text(
                                    '🎮 CHƠI NGAY',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ValueListenableBuilder<bool>(
                                valueListenable:
                                    InternetStatusService.instance.hasInternet,
                                builder: (context, hasInternet, _) {
                                  return Column(
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              hasInternet
                                                  ? () {
                                                    Navigator.pushNamed(
                                                      context,
                                                      '/leaderboard',
                                                    );
                                                  }
                                                  : null,
                                          icon: Icon(
                                            hasInternet
                                                ? Icons.leaderboard_rounded
                                                : Icons.wifi_off_rounded,
                                          ),
                                          label: const Text(
                                            'BẢNG XẾP HẠNG',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFF1565C0,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFF90CAF9),
                                              width: 1.8,
                                            ),
                                            disabledForegroundColor:
                                                const Color(0xFF90A4AE),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        hasInternet
                                            ? ''
                                            : 'Mất internet, không thể mở bảng xếp hạng',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              hasInternet
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFb71c1c),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepthGridPainter extends CustomPainter {
  const _DepthGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final horizonY = size.height * 0.52;

    final floorPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF42A5F5).withValues(alpha: 0.0),
              const Color(0xFF1565C0).withValues(alpha: 0.13),
              const Color(0xFF0D47A1).withValues(alpha: 0.22),
            ],
          ).createShader(Rect.fromLTWH(0, horizonY, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
      floorPaint,
    );

    final linePaint =
        Paint()
          ..color = const Color(0xFF90CAF9).withValues(alpha: 0.20)
          ..strokeWidth = 1;

    for (int i = 0; i <= 7; i++) {
      final t = i / 7;
      final y = horizonY + (size.height - horizonY) * t * t;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    for (int i = -6; i <= 6; i++) {
      final xBottom = size.width / 2 + (i * size.width * 0.13);
      canvas.drawLine(
        Offset(size.width / 2, horizonY),
        Offset(xBottom, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SwatAnimation extends StatelessWidget {
  final AnimationController controller;

  const _SwatAnimation({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 100,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final progress = controller.value;
          final isSwatFrame = progress >= 0.62 && progress <= 0.94;
          if (isSwatFrame) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF5350).withValues(alpha: 0.24),
                    shape: BoxShape.circle,
                  ),
                ),
                const Icon(
                  Icons.close_rounded,
                  size: 54,
                  color: Color(0xFFc62828),
                ),
              ],
            );
          }

          final bob = sin(progress * pi * 2) * 8;
          final tilt = sin(progress * pi * 4) * 0.15;
          return Transform.translate(
            offset: Offset(bob, 0),
            child: Transform.rotate(
              angle: tilt,
              child: const _MenuFlyIcon(size: 66),
            ),
          );
        },
      ),
    );
  }
}

class _MenuFlyIcon extends StatelessWidget {
  final double size;

  const _MenuFlyIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MenuFlyPainter()),
    );
  }
}

class _MenuFlyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final wingPaint =
        Paint()
          ..color = const Color(0xFFE3F2FD)
          ..style = PaintingStyle.fill;
    final wingBorder =
        Paint()
          ..color = const Color(0xFF90A4AE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    final bodyPaint = Paint()..color = const Color(0xFF263238);
    final bodyLight = Paint()..color = const Color(0xFF546E7A);
    final eyePaint = Paint()..color = const Color(0xFFD32F2F);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          center.dx - size.width * 0.16,
          center.dy - size.height * 0.12,
        ),
        width: size.width * 0.35,
        height: size.height * 0.22,
      ),
      wingPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          center.dx + size.width * 0.16,
          center.dy - size.height * 0.12,
        ),
        width: size.width * 0.35,
        height: size.height * 0.22,
      ),
      wingPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          center.dx - size.width * 0.16,
          center.dy - size.height * 0.12,
        ),
        width: size.width * 0.35,
        height: size.height * 0.22,
      ),
      wingBorder,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          center.dx + size.width * 0.16,
          center.dy - size.height * 0.12,
        ),
        width: size.width * 0.35,
        height: size.height * 0.22,
      ),
      wingBorder,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.28,
        height: size.height * 0.48,
      ),
      bodyPaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - size.height * 0.06),
        width: size.width * 0.14,
        height: size.height * 0.2,
      ),
      bodyLight,
    );

    canvas.drawCircle(
      Offset(center.dx, center.dy - size.height * 0.28),
      size.width * 0.11,
      bodyPaint,
    );

    canvas.drawCircle(
      Offset(center.dx - size.width * 0.05, center.dy - size.height * 0.3),
      size.width * 0.03,
      eyePaint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.05, center.dy - size.height * 0.3),
      size.width * 0.03,
      eyePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0D47A1),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}
