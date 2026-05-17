import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../widgets/chest_painter.dart';
import '../widgets/coin_burst.dart';

class ChestScreen extends StatefulWidget {
  const ChestScreen({super.key});

  @override
  State<ChestScreen> createState() => _ChestScreenState();
}

class _ChestScreenState extends State<ChestScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _secondsRemaining = 10787; // 02:59:47

  // Idle floating animation
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _startTimer();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _floatController.dispose();
    super.dispose();
  }

  void _openChest() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => const ChestOpeningDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    int h = _secondsRemaining ~/ 3600;
    int m = (_secondsRemaining % 3600) ~/ 60;
    int s = _secondsRemaining % 60;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF131326)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Treasure Chest',
          style: TextStyle(
            color: Color(0xFF131326),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Open chests and get amazing rewards!',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // 3D Chest with floating animation
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Gold glow
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFFFD700).withOpacity(0.25),
                              const Color(0xFFFFD700).withOpacity(0.05),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      // 3D Chest
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CustomPaint(
                          painter: ChestPainter(openAmount: 0.0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Timer Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Next chest unlocks in',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTimeUnit(
                            h.toString().padLeft(2, '0'), 'Hours'),
                        const _TimeSeparator(),
                        _buildTimeUnit(
                            m.toString().padLeft(2, '0'), 'Minutes'),
                        const _TimeSeparator(),
                        _buildTimeUnit(
                            s.toString().padLeft(2, '0'), 'Seconds'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _PrimaryButton(text: 'Open', onTap: _openChest),
                  const SizedBox(height: 16),
                  _SecondaryButton(
                    text: 'Open Instantly — Watch Ad',
                    icon: Icons.ondemand_video,
                    onTap: _openChest,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Color(0xFF131326),
            letterSpacing: -1,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Separator ───
class _TimeSeparator extends StatelessWidget {
  const _TimeSeparator();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(':',
          style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF131326))),
    );
  }
}

// ─── Primary Button ───
class _PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  const _PrimaryButton({required this.text, required this.onTap});
  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(widget.text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ─── Secondary Button ───
class _SecondaryButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  const _SecondaryButton(
      {required this.text, required this.icon, required this.onTap});
  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.3), width: 1.5),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.text,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Icon(widget.icon, color: AppColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Chest Opening Dialog ───
class ChestOpeningDialog extends StatefulWidget {
  const ChestOpeningDialog({super.key});
  @override
  State<ChestOpeningDialog> createState() => _ChestOpeningDialogState();
}

class _ChestOpeningDialogState extends State<ChestOpeningDialog>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _openController;
  late AnimationController _rewardController;

  late Animation<double> _shakeAnim;
  late Animation<double> _openAnim;
  late Animation<double> _rewardScale;
  late Animation<double> _rewardOpacity;

  int _earnedCoins = 0;
  bool _showReward = false;
  bool _burstCoins = false;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _openController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _rewardController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: 0.0), weight: 1),
    ]).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _openAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _openController, curve: Curves.easeOutBack));

    _rewardScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _rewardController, curve: Curves.elasticOut));

    _rewardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _rewardController, curve: Curves.easeIn));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _shakeController.forward();
    await _openController.forward();
    if (mounted) {
      setState(() {
        _burstCoins = true;
      });
    }
    // Wait for the coin burst to fully finish (2 seconds) before popping up the reward
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      setState(() {
        _showReward = true;
        _earnedCoins = 500;
      });
      _rewardController.forward();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _openController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [_shakeController, _openController, _rewardController]),
        builder: (context, _) {
          return SizedBox(
            width: 300,
            height: 450,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Coin Burst Animation (rendered behind the reward popup, coming out of the chest)
                if (!_showReward)
                  Positioned.fill(
                    child: CoinBurstWidget(isTriggered: _burstCoins),
                  ),

                // Chest with open animation
                if (!_showReward)
                  Positioned(
                    top: 100,
                    child: Transform.rotate(
                      angle: _shakeAnim.value,
                      child: SizedBox(
                        width: 240,
                        height: 240,
                        child: CustomPaint(
                          painter: ChestPainter(openAmount: _openAnim.value),
                        ),
                      ),
                    ),
                  ),

                // Reward card
                if (_showReward)
                  Center(
                    child: Opacity(
                      opacity: _rewardOpacity.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _rewardScale.value.clamp(0.0, 1.5),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withOpacity(0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🎉', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 8),
                              const Text(
                                'Congratulations!',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF131326),
                                ),
                              ),
                              const SizedBox(height: 12),
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
                                      '+$_earnedCoins RBX',
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
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                  ),
                                  child: const Text('Claim Reward',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
