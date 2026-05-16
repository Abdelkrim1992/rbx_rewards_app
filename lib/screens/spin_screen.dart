import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SpinScreen extends StatefulWidget {
  final VoidCallback onBack;

  const SpinScreen({super.key, required this.onBack});

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _animation;
  late Animation<double> _pulseAnimation;
  bool _isSpinning = false;
  int _freeSpins = 1;
  double _adButtonScale = 1.0;

  final List<_WheelSegment> segments = const [
    _WheelSegment(label: '100', sublabel: 'RBX', color: Color(0xFF9B5CFF)),
    _WheelSegment(label: '300', sublabel: 'RBX', color: Color(0xFF7B3FE4)),
    _WheelSegment(label: '500', sublabel: 'RBX', color: Color(0xFFB370FF)),
    _WheelSegment(label: '2K', sublabel: 'RBX', color: Color(0xFF6A2FD8)),
    _WheelSegment(label: 'JACKPOT', sublabel: 'Huge!', color: Color(0xFFFFCC44)),
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

  void _spin() {
    if (_isSpinning || _freeSpins == 0) return;
    final random = Random();
    final targetSegment = random.nextInt(6);
    final baseRotations = 5 + random.nextInt(3);
    final segmentAngle = (2 * pi) / 6;
    final targetAngle =
        baseRotations * 2 * pi + targetSegment * segmentAngle + segmentAngle / 2;

    _animation = Tween<double>(
      begin: _animation.value ?? 0,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    setState(() {
      _isSpinning = true;
      _freeSpins--;
    });

    _pulseController.stop();

    _controller.reset();
    _controller.forward().then((_) {
      setState(() {
        _isSpinning = false;
      });
      _pulseController.repeat(reverse: true);
      _showWinDialog(segments[targetSegment].label);
    });
  }

  void _showWinDialog(String prize) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(
                prize == 'JACKPOT' ? 'JACKPOT!!!' : 'You won $prize RBX!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF131326),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Coins have been added to your balance.',
                style: TextStyle(fontSize: 14, color: Color(0xFF868A9F)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              StatefulBuilder(
                builder: (context, setDialogState) {
                  double scale = 1.0;
                  return GestureDetector(
                    onTapDown: (_) => setDialogState(() => scale = 0.95),
                    onTapUp: (_) {
                      setDialogState(() => scale = 1.0);
                      Navigator.pop(ctx);
                    },
                    onTapCancel: () => setDialogState(() => scale = 1.0),
                    child: AnimatedScale(
                      scale: scale,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'Awesome!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final wheelSize = screenWidth * 0.78;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Nav bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
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
                  const Spacer(),
                  const Text(
                    'Spin & Win',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF131326),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Image.network(
                          AppAssets.goldCoin,
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.monetization_on,
                            size: 20,
                            color: Color(0xFFFFCC44),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '525',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF131326),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
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
                                      color: AppColors.primary.withOpacity(0.2),
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
                                      final value = _isSpinning || _controller.value > 0
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
                                      child: CustomPaint(
                                        size: Size(wheelSize, wheelSize),
                                        painter: _WheelPainter(segments),
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
                                          scale: _isSpinning ? 1.0 : _pulseAnimation.value,
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
                                            colors: [Colors.white, Color(0xFFF8F9FF)],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 15,
                                              offset: const Offset(0, 8),
                                            ),
                                            BoxShadow(
                                              color: AppColors.primary.withOpacity(0.3),
                                              blurRadius: 2,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                _isSpinning ? '...' : 'SPIN',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.primary,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                              if (!_isSpinning)
                                                const Icon(Icons.touch_app, size: 14, color: AppColors.primaryText),
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
                                  Icon(Icons.location_on, color: AppColors.primary, size: 44),
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
                      'Free Spins: $_freeSpins',
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
                      onTapUp: (_) {
                        setState(() {
                          _adButtonScale = 1.0;
                          _freeSpins++;
                        });
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
                              const Icon(Icons.play_circle_fill, color: Colors.white, size: 22),
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
                          description: 'Watch a short video to get another chance.',
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
        ..shader = segmentGradient.createShader(Rect.fromCircle(center: center, radius: radius))
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
      final textRadius = radius * 0.65;
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
                ? const Color(0xFF5C3D00)
                : Colors.white,
            fontSize: segments[i].label.length > 3 ? 10 : 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
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
