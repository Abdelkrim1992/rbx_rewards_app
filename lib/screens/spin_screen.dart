import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/refreshable_scroll.dart';

class SpinScreen extends StatefulWidget {
  final VoidCallback onBack;

  const SpinScreen({super.key, required this.onBack});

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _animation;
  late Animation<double> _pulseAnimation;
  bool _isSpinning = false;
  double _adButtonScale = 1.0;

  final List<_WheelSegment> segments = const [
    _WheelSegment(label: '100', sublabel: 'RBX', color: Color(0xFF9B5CFF)),
    _WheelSegment(label: '300', sublabel: 'RBX', color: Color(0xFF7B3FE4)),
    _WheelSegment(label: '500', sublabel: 'RBX', color: Color(0xFFB370FF)),
    _WheelSegment(label: '2K', sublabel: 'RBX', color: Color(0xFF6A2FD8)),
    _WheelSegment(
        label: 'JACKPOT',
        sublabel: 'Huge!',
        color: Color.fromARGB(255, 160, 122, 16)),
    _WheelSegment(label: '1K', sublabel: 'RBX', color: Color(0xFF8847F5)),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animation = AlwaysStoppedAnimation(0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int _pickWeightedSegment(Random random) {
    final weights = [25, 25, 20, 10, 5, 15]; // 100, 300, 500, 2K, JACKPOT, 1K
    final total = weights.fold<int>(0, (sum, w) => sum + w);
    var roll = random.nextInt(total);
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return i;
    }
    return 0;
  }

  Future<void> _spin() async {
    final appState = context.read<AppState>();
    if (_isSpinning || appState.spinFreeSpins == 0) return;
    final random = Random();
    final targetSegment = _pickWeightedSegment(random);
    final baseRotations = 2 + random.nextInt(6);
    final segmentAngle = (2 * pi) / 6;
    final targetAngle = baseRotations * 2 * pi +
        targetSegment * segmentAngle +
        segmentAngle / 2;

    _animation = Tween<double>(
      begin: _animation.value ?? 0,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    setState(() {
      _isSpinning = true;
    });

    _pulseController.stop();

    _controller.reset();
    _controller.forward().then((_) async {
      final prizeIndex =
          (segments.length - 1 - targetSegment) % segments.length;
      final prize = segments[prizeIndex].label;
      final reward = _prizeToCoins(prize);

      if (!mounted) return;

      setState(() {
        _isSpinning = false;
      });
      _pulseController.repeat(reverse: true);
      _showWinDialog(prize, reward);
    });
  }

  int _prizeToCoins(String prize) {
    switch (prize) {
      case '1K':
        return 1000;
      case '2K':
        return 2000;
      case 'JACKPOT':
        return 5000;
      default:
        return int.tryParse(prize) ?? 0;
    }
  }

  void _showWinDialog(String prize, int reward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => SpinRewardDialog(
        prize: prize,
        reward: reward,
        onClaim: () async {
          final appState = context.read<AppState>();
          // Always consume locally and award coins; server sync is best-effort.
          final consumed = await appState.consumeLocalSpin();
          if (!consumed) {
            throw Exception('No spins remaining.');
          }
          await appState.addCoins(reward, source: 'spin');
          // Best-effort server sync in background
          try {
            await appState.useSpin();
          } catch (_) {}
        },
      ),
    ).then((_) {
      // Cooldown is managed by AppState; no local timer needed
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final freeSpins = appState.spinFreeSpins;
    final cooldownRemaining = appState.spinCooldownRemaining;

    final screenWidth = MediaQuery.of(context).size.width;
    final wheelSize = screenWidth * 0.78;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!_isSpinning) {
          widget.onBack();
          return;
        }
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'Leave Spin?',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: const Color(0xFF131326),
              ),
            ),
            content: Text(
              'Your spin is in progress. Are you sure you want to leave?',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF4A4B60),
                height: 1.4,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F1FB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF868A9F),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF1744).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Leave',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        if (shouldLeave == true && mounted) {
          widget.onBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Nav bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: widget.onBack,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: AppColors.purple,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const Text(
                        'Spin & Win',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF131326),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: RefreshableScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppLayout.screenPadding),
                  child: Column(
                    children: [
                      // 3D Wheel Container
                      SizedBox(
                        height: wheelSize + 60,
                        child: Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            // Perspective Shadow
                            Positioned(
                              top: 50,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateX(1.1),
                                alignment: Alignment.center,
                                child: Container(
                                  width: wheelSize * 0.9,
                                  height: wheelSize * 0.9,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.primary.withOpacity(0.2),
                                        blurRadius: 40,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // The Main Wheel with 3D Tilt
                            Positioned(
                              top: 30,
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateX(-0.35), // The 3D tilt
                                alignment: Alignment.center,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Wheel Base/Depth Effect
                                    Container(
                                      width: wheelSize + 10,
                                      height: wheelSize + 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            const Color(0xFF4A2BC2),
                                            const Color(0xFF2E1B7A),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Rotating Part
                                    AnimatedBuilder(
                                      animation: _controller,
                                      builder: (context, child) {
                                        final value =
                                            _isSpinning || _controller.value > 0
                                                ? _animation.value
                                                : 0.0;
                                        return Transform.rotate(
                                          angle: value,
                                          child: child,
                                        );
                                      },
                                      child: SizedBox(
                                        width: wheelSize,
                                        height: wheelSize,
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: CustomPaint(
                                                painter:
                                                    _WheelPainter(segments),
                                              ),
                                            ),
                                            ...List.generate(segments.length,
                                                (i) {
                                              final segmentAngle =
                                                  (2 * pi) / segments.length;
                                              final startAngle =
                                                  i * segmentAngle - pi / 2;
                                              final textAngle =
                                                  startAngle + segmentAngle / 2;

                                              final center = wheelSize / 2;
                                              final imgRadius = center * 0.42;
                                              final imgX = center +
                                                  imgRadius * cos(textAngle);
                                              final imgY = center +
                                                  imgRadius * sin(textAngle);

                                              return Positioned(
                                                left: imgX - 15,
                                                top: imgY - 12,
                                                child: Transform.rotate(
                                                  angle: textAngle + pi / 2,
                                                  child: Image.asset(
                                                    AppAssets.goldRbxCoin,
                                                    width: 25,
                                                    height: 25,
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Center SPIN button (Fixed, not rotating)
                                    GestureDetector(
                                      onTap: _spin,
                                      child: AnimatedBuilder(
                                        animation: _pulseAnimation,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale:
                                                _isSpinning || (freeSpins == 0)
                                                    ? 1.0
                                                    : _pulseAnimation.value,
                                            child: child,
                                          );
                                        },
                                        child: Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            gradient: const RadialGradient(
                                              colors: [
                                                Colors.white,
                                                Color(0xFFF8F9FF)
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                blurRadius: 15,
                                                offset: const Offset(0, 8),
                                              ),
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withOpacity(0.3),
                                                blurRadius: 2,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  _isSpinning
                                                      ? '...'
                                                      : (freeSpins == 0)
                                                          ? _formatDuration(
                                                              cooldownRemaining)
                                                          : 'SPIN',
                                                  style: TextStyle(
                                                    fontSize: (freeSpins == 0)
                                                        ? 14
                                                        : 16,
                                                    fontWeight: FontWeight.w900,
                                                    color: (freeSpins == 0)
                                                        ? Colors.grey
                                                        : AppColors.primary,
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                                if (!_isSpinning &&
                                                    !(freeSpins == 0))
                                                  const Icon(Icons.touch_app,
                                                      size: 14,
                                                      color: AppColors
                                                          .primaryText),
                                                if (!_isSpinning &&
                                                    (freeSpins == 0))
                                                  const Icon(Icons.lock_clock,
                                                      size: 14,
                                                      color: Colors.grey),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Top Indicator
                            Positioned(
                              top: 5,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(Icons.location_on,
                                        color: AppColors.primary, size: 44),
                                    Positioned(
                                      top: 8,
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
                      // Free spins info
                      Text(
                        'Free Spins: $freeSpins',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF131326),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Watch Ad button
                      GestureDetector(
                        onTapDown: (_) => setState(() => _adButtonScale = 0.95),
                        onTapUp: (_) async {
                          setState(() => _adButtonScale = 1.0);
                          await context.read<AppState>().addFreeSpin();
                        },
                        onTapCancel: () => setState(() => _adButtonScale = 1.0),
                        child: AnimatedScale(
                          scale: _adButtonScale,
                          duration: const Duration(milliseconds: 100),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_circle_fill,
                                    color: Colors.white, size: 22),
                                const SizedBox(width: 8),
                                const Text(
                                  'Watch Ad for Extra Spin',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // How to Play Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How to Spin & Win',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF131326),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _HowToStep(
                            icon: Icons.auto_awesome,
                            title: 'Try Your Luck',
                            description: 'Spin daily to win up to 5,000 RBX.',
                            color: const Color(0xFF9B5CFF),
                          ),
                          const SizedBox(height: 8),
                          _HowToStep(
                            icon: Icons.play_circle_outline,
                            title: 'Get More Spins',
                            description:
                                'Watch a short video to get another chance.',
                            color: const Color(0xFF6B4BF4),
                          ),
                          const SizedBox(height: 8),
                          _HowToStep(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Collect & Redeem',
                            description: 'Exchange coins for real items.',
                            color: const Color(0xFF4A2BC2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowToStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _HowToStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F2F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF131326),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF868A9F),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelSegment {
  final String label;
  final String sublabel;
  final Color color;

  const _WheelSegment({
    required this.label,
    required this.sublabel,
    required this.color,
  });
}

class _WheelPainter extends CustomPainter {
  final List<_WheelSegment> segments;

  _WheelPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = (2 * pi) / segments.length;

    // Outer ring shadow
    final shadowPaint = Paint()
      ..color = const Color(0x22664DFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius, shadowPaint);

    for (int i = 0; i < segments.length; i++) {
      final startAngle = i * segmentAngle - pi / 2;

      // Gradient for segment
      final segmentGradient = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          segments[i].color,
          segments[i].color.withOpacity(0.8),
        ],
      );

      final paint = Paint()
        ..shader = segmentGradient
            .createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      // Segment border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        segmentAngle,
        true,
        borderPaint,
      );

      // Label
      final textAngle = startAngle + segmentAngle / 2;
      final textRadius =
          radius * 0.72; // Moved slightly outward to give space for the coin
      final textX = center.dx + textRadius * cos(textAngle);
      final textY = center.dy + textRadius * sin(textAngle);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + pi / 2);

      final textPainter = TextPainter(
        text: TextSpan(
          text: segments[i].label,
          style: TextStyle(
            color: segments[i].color == const Color(0xFFFFCC44)
                ? const Color.fromARGB(255, 50, 33, 0)
                : Colors.white,
            fontSize: segments[i].label.length > 3 ? 13 : 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // Outer Gold rim
    final rimPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFD700)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(center, radius - 5, rimPaint);

    // Decorative dots around the rim
    final dotPaint = Paint()..color = Colors.white;
    const dotCount = 12;
    for (int i = 0; i < dotCount; i++) {
      final angle = (i * 2 * pi) / dotCount;
      final dotX = center.dx + (radius - 5) * cos(angle);
      final dotY = center.dy + (radius - 5) * sin(angle);
      canvas.drawCircle(Offset(dotX, dotY), 2.5, dotPaint);

      // Add a glow to dots
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(dotX, dotY), 4, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Spin Reward 3D Popup ───────────────────────────────────────────

class SpinRewardDialog extends StatefulWidget {
  final String prize;
  final int reward;
  final Future<void> Function() onClaim;

  const SpinRewardDialog({
    super.key,
    required this.prize,
    required this.reward,
    required this.onClaim,
  });

  @override
  State<SpinRewardDialog> createState() => _SpinRewardDialogState();
}

class _SpinRewardDialogState extends State<SpinRewardDialog>
    with TickerProviderStateMixin {
  // Separate controllers: rotation repeats, entrance plays once
  late AnimationController _burstRotationController;
  late AnimationController _burstEntranceController;
  late AnimationController _coinFlipController;
  late AnimationController _cardController;
  late AnimationController _particleController;
  late AnimationController _shimmerController;

  late Animation<double> _burstRotation;
  late Animation<double> _burstScale;
  late Animation<double> _burstOpacity;
  late Animation<double> _coinFlip;
  late Animation<double> _coinScale;
  late Animation<double> _cardScale;
  late Animation<double> _cardOpacity;
  late Animation<double> _shimmer;

  final List<_ConfettiParticle> _particles = [];
  bool _disposed = false;
  bool _animationComplete = false;
  bool _isClaiming = false;
  String? _claimError;

  @override
  void initState() {
    super.initState();

    // Repeating rotation for light burst rays
    _burstRotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _burstRotation = Tween<double>(begin: 0, end: 2 * pi).animate(
      _burstRotationController,
    );

    // One-shot entrance for scale/opacity
    _burstEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _burstScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _burstEntranceController, curve: Curves.easeOutCubic),
    );

    _burstOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _burstEntranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // 3D coin flip — use Curves.easeOut (not easeOutBack which overshoots > 1.0)
    _coinFlipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _coinFlip = Tween<double>(begin: 0.0, end: 6 * pi).animate(
      CurvedAnimation(parent: _coinFlipController, curve: Curves.easeOutCubic),
    );

    _coinScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 3),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 2),
    ]).animate(CurvedAnimation(
      parent: _coinFlipController,
      curve: Curves.easeOut,
    ));

    // Card pop-in — use Curves.easeOut (not easeOutBack)
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.08), weight: 6),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 0.96), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0), weight: 2),
    ]).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOut,
    ));

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Confetti particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    final rng = Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(_ConfettiParticle(
        angle: rng.nextDouble() * 2 * pi,
        speed: 80 + rng.nextDouble() * 160,
        size: 4 + rng.nextDouble() * 8,
        color: [
          const Color(0xFFFFD700),
          const Color(0xFFFFA500),
          const Color(0xFF9B5CFF),
          const Color(0xFF6035EE),
          const Color(0xFFFF6B9D),
          Colors.white,
        ][rng.nextInt(6)],
        rotationSpeed: (rng.nextDouble() - 0.5) * 8,
      ));
    }

    // Shimmer on button
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
      _shimmerController,
    );

    _startSequence();
  }

  void _startSequence() async {
    // Start burst entrance + rotation immediately
    _burstEntranceController.forward();

    // Coin flip starts after a short delay
    await Future.delayed(const Duration(milliseconds: 200));
    if (_disposed) return;
    _coinFlipController.forward();

    // Confetti particles erupt
    await Future.delayed(const Duration(milliseconds: 400));
    if (_disposed) return;
    _particleController.forward();

    // Wait for coin animation to fully complete
    await Future.delayed(const Duration(milliseconds: 1800));
    if (_disposed) return;

    // Hide coin and burst
    setState(() {
      _animationComplete = true;
    });
    // Stop repeating controllers
    _burstRotationController.stop();
    _shimmerController.stop();

    // Now slide in the reward card
    _cardController.forward();
  }

  @override
  void dispose() {
    _disposed = true;
    _burstRotationController.dispose();
    _burstEntranceController.dispose();
    _coinFlipController.dispose();
    _cardController.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isJackpot = widget.prize == 'JACKPOT';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _burstRotationController,
            _burstEntranceController,
            _coinFlipController,
            _cardController,
            _particleController,
          ]),
          builder: (context, _) {
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (!_animationComplete) ...[
                  // ── Rotating light burst ──
                  Opacity(
                    opacity: _burstOpacity.value.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: _burstRotation.value,
                      child: Transform.scale(
                        scale: _burstScale.value.clamp(0.0, 2.0),
                        child: CustomPaint(
                          size: const Size(320, 320),
                          painter: _LightRaysPainter(
                            color: isJackpot
                                ? const Color(0xFFFFD700)
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Circular glow ──
                  Opacity(
                    opacity: _burstOpacity.value.clamp(0.0, 1.0),
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (isJackpot
                                    ? const Color(0xFFFFD700)
                                    : AppColors.primary)
                                .withOpacity(0.4),
                            (isJackpot
                                    ? const Color(0xFFFFD700)
                                    : AppColors.primary)
                                .withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Confetti particles ──
                  ..._buildParticles(),

                  // ── 3D Flipping Coin ──
                  Transform.scale(
                    scale: _coinScale.value.clamp(0.0, 2.0),
                    child: Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002) // perspective
                        ..rotateY(_coinFlip.value),
                      alignment: Alignment.center,
                      child: _buildCoinFace(),
                    ),
                  ),
                ],

                // ── Reward card ──
                if (_animationComplete)
                  Center(
                    child: Opacity(
                      opacity: _cardOpacity.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _cardScale.value.clamp(0.0, 2.0),
                        child: _buildRewardCard(isJackpot),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCoinFace() {
    // Show front face when coin faces camera, back when rotated away
    final normalizedAngle = (_coinFlip.value % (2 * pi));
    final showFront = normalizedAngle < pi / 2 || normalizedAngle > 3 * pi / 2;

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: showFront
              ? [const Color(0xFFFFE066), const Color(0xFFFFB300)]
              : [const Color(0xFFD4A017), const Color(0xFF9E7700)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.5),
            blurRadius: 24,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFFE599),
          width: 3,
        ),
      ),
      child: Center(
        child: showFront
            ? Image.asset(
                AppAssets.goldRbxCoin,
                width: 60,
                height: 60,
                errorBuilder: (_, __, ___) => const Text(
                  'R',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7A5800),
                  ),
                ),
              )
            : const Text(
                '✦',
                style: TextStyle(
                  fontSize: 32,
                  color: Color(0xFFB8860B),
                ),
              ),
      ),
    );
  }

  List<Widget> _buildParticles() {
    final progress = _particleController.value;
    if (progress == 0) return [];

    return _particles.map((p) {
      final distance = p.speed * progress;
      final x = cos(p.angle) * distance;
      final y = sin(p.angle) * distance - 40 * progress * progress; // gravity
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final rotation = p.rotationSpeed * progress * pi;

      return Positioned(
        left: 0,
        right: 0,
        top: 0,
        bottom: 0,
        child: Center(
          child: Transform.translate(
            offset: Offset(x, y),
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: rotation,
                child: Container(
                  width: p.size,
                  height: p.size * 0.6,
                  decoration: BoxDecoration(
                    color: p.color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: p.color.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildRewardCard(bool isJackpot) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isJackpot ? const Color(0xFFFFD700) : AppColors.primary)
                .withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          const BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            isJackpot ? '🎰  JACKPOT!  🎰' : '🎉  You Won!',
            style: TextStyle(
              fontSize: isJackpot ? 22 : 20,
              fontWeight: FontWeight.w800,
              color:
                  isJackpot ? const Color(0xFFD4A017) : const Color(0xFF131326),
              letterSpacing: isJackpot ? 1.5 : 0,
            ),
          ),
          const SizedBox(height: 8),

          // Prize amount
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  AppAssets.goldRbxCoin,
                  width: 28,
                  height: 28,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFFFCC44),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '+${widget.reward} RBX',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Text(
            'Tap claim to add to your balance',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          if (_claimError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _claimError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
            ),

          // Claim button — premium styled
          _InteractiveCard(
            onTap: _isClaiming
                ? null
                : () async {
                    setState(() {
                      _isClaiming = true;
                      _claimError = null;
                    });
                    try {
                      await widget.onClaim();
                      if (mounted) Navigator.of(context).pop();
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          _isClaiming = false;
                          _claimError =
                              e.toString().replaceFirst('Exception: ', '');
                        });
                      }
                    }
                  },
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: _isClaiming ? null : AppColors.primaryGradient,
                color: _isClaiming ? const Color(0xFFE2E2F5) : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _isClaiming
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              alignment: Alignment.center,
              child: _isClaiming
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.purple),
                      ),
                    )
                  : const Text(
                      'Claim Reward',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double rotationSpeed;

  _ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotationSpeed,
  });
}

class _LightRaysPainter extends CustomPainter {
  final Color color;

  _LightRaysPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const rayCount = 12;

    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 2 * pi) / rayCount;
      final nextAngle = ((i + 0.4) * 2 * pi) / rayCount;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        )
        ..lineTo(
          center.dx + radius * cos(nextAngle),
          center.dy + radius * sin(nextAngle),
        )
        ..close();

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(0.3),
            color.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _InteractiveCard({required this.child, this.onTap});

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTap: () {
        setState(() => _scale = 1.0);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
