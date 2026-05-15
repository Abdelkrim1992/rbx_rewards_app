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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  int _freeSpins = 1;
  String? _wonPrize;

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
  }

  @override
  void dispose() {
    _controller.dispose();
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
      _wonPrize = null;
      _freeSpins--;
    });

    _controller.reset();
    _controller.forward().then((_) {
      setState(() {
        _isSpinning = false;
        _wonPrize = segments[targetSegment].label;
      });
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
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
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
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Wheel
                    SizedBox(
                      height: wheelSize + 40,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          // Pointer
                          Positioned(
                            top: 0,
                            child: Column(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x44664DFF),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                CustomPaint(
                                  size: const Size(20, 12),
                                  painter: _TrianglePainter(AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                          // Wheel
                          Positioned(
                            top: 22,
                            child: AnimatedBuilder(
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
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Wheel segments
                                    CustomPaint(
                                      size: Size(wheelSize, wheelSize),
                                      painter: _WheelPainter(segments),
                                    ),
                                    // Center SPIN button
                                    GestureDetector(
                                      onTap: _spin,
                                      child: Container(
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.primary,
                                            width: 4,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x44664DFF),
                                              blurRadius: 16,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            _isSpinning ? '...' : 'SPIN',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Free spins info
                    Text(
                      'Free Spins: $_freeSpins',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF131326),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Watch Ad button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _freeSpins++);
                        },
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.purple.withOpacity(0.3),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Watch Ad for Extra Spin',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.purple,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Possible Rewards Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Possible Rewards',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF131326),
                                ),
                              ),
                              Text('✨', style: TextStyle(fontSize: 20)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 2.5,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            children: const [
                              _RewardItem(amount: '100', label: 'RBX Coins'),
                              _RewardItem(amount: '300', label: 'RBX Coins'),
                              _RewardItem(amount: '500', label: 'RBX Coins'),
                              _RewardItem(amount: '1K', label: 'RBX Coins'),
                              _RewardItem(amount: '2K', label: 'RBX Coins'),
                              _RewardItem(amount: 'JACKPOT', label: 'Huge Reward'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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

class _RewardItem extends StatelessWidget {
  final String amount;
  final String label;

  const _RewardItem({required this.amount, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Image.network(
            AppAssets.goldCoin,
            width: 22,
            height: 22,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.monetization_on,
              size: 22,
              color: Color(0xFFFFCC44),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.secondaryText,
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
      final paint = Paint()
        ..color = segments[i].color
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
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 4),
        startAngle,
        segmentAngle,
        true,
        borderPaint,
      );

      // Label
      final textAngle = startAngle + segmentAngle / 2;
      final textRadius = radius * 0.62;
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
            fontSize: segments[i].label.length > 3 ? 9 : 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
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

    // Gold outer ring
    final ringPaint = Paint()
      ..color = const Color(0xFFFFCC44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius - 4, ringPaint);

    // Inner white circle background for SPIN button
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 50, centerPaint);
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
