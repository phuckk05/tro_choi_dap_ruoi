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

class _MainMenuScreenState extends State<MainMenuScreen> {
  final TextEditingController _nameController = TextEditingController();

  bool _loadingProfile = true;
  int _currentRecord = 0;
  int? _currentRecordSeconds;

  @override
  void initState() {
    super.initState();
    _initProfile();
  }

  Future<void> _initProfile() async {
    final profile = await PlayerProfileService.instance.ensureProfile();
    int best = 0;
    int? bestSeconds;
    try {
      final myBest = await ScoreRepository.instance.getPlayerBestRecord(
        profile.playerId,
      );
      if (myBest != null) {
        best = myBest.bestScore;
        bestSeconds = myBest.playedDurationSeconds;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _setNameField(profile.playerName);
      _currentRecord = best;
      _currentRecordSeconds = bestSeconds;
      _loadingProfile = false;
    });
  }

  String _formatDurationCompact(int? seconds) {
    if (seconds == null) return '--:--';
    final safe = seconds < 0 ? 0 : seconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final remainSeconds = safe % 60;
    final secondText = remainSeconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}\'$secondText';
    }
    return '$minutes\'$secondText';
  }

  void _setNameField(String value) {
    _nameController
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
  }

  Future<void> _startGame() async {
    final name = _nameController.text.trim();
    _setNameField(name);
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

    final updatedProfile = await PlayerProfileService.instance.ensureProfile(
      preferredName: name,
    );
    if (mounted) {
      setState(() {
        _setNameField(updatedProfile.playerName);
      });
    }
    await ScoreRepository.instance.syncPlayerProfileName(updatedProfile);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/game');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset > 0 ? 16 : 0),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'ĐẬP RUỒI',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2E4A35),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF4EA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFB9D2B5)),
                          ),
                          child: Text(
                            'Kỷ lục: $_currentRecord ruồi | Thời gian: ${_formatDurationCompact(_currentRecordSeconds)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2F5D3A),
                            ),
                          ),
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadingProfile ? null : _startGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F6F52),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Chơi',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<bool>(
                          valueListenable:
                              InternetStatusService.instance.hasInternet,
                          builder: (context, hasInternet, _) {
                            return OutlinedButton.icon(
                              onPressed:
                                  hasInternet
                                      ? () => Navigator.pushNamed(
                                        context,
                                        '/leaderboard',
                                      )
                                      : null,
                              icon: Icon(
                                hasInternet
                                    ? Icons.leaderboard_rounded
                                    : Icons.wifi_off_rounded,
                              ),
                              label: Text(
                                hasInternet
                                    ? 'Bảng xếp hạng'
                                    : 'Không có internet',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF5A4A3C),
                                side: const BorderSide(
                                  color: Color(0xFFCDBCA4),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
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
    );
  }
}

// ignore: unused_element
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

// ignore: unused_element
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

// ignore: unused_element
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
