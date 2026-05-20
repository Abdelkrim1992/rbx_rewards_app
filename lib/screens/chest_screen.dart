import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chest_painter.dart';
import '../widgets/coin_burst.dart';
import '../widgets/game_prefs.dart';

class ChestScreen extends StatefulWidget {
  const ChestScreen({super.key});

  @override
  State<ChestScreen> createState() => _ChestScreenState();
}

class _ChestScreenState extends State<ChestScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _secondsRemaining = 0; // Active/Openable by default

  int _balance = 0;

  // Idle floating animation
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _loadChestStatus();
    _loadBalance();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadChestStatus() async {
    final remaining = await GamePrefs.getChestSecondsRemaining();
    if (!mounted) return;
    setState(() {
      _secondsRemaining = remaining;
    });
    if (remaining > 0) {
      _timer?.cancel();
      _startTimer();
    }
  }

  Future<void> _loadBalance() async {
    final coins = await GamePrefs.getCoins();
    if (!mounted) return;
    setState(() {
      _balance = coins;
    });
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
    showDialog<int>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => const ChestOpeningDialog(),
    ).then((coinsEarned) async {
      if (coinsEarned != null) {
        await GamePrefs.setChestUnlockTime(10800); // Reset to 3 hours
        if (!mounted) return;
        setState(() {
          _secondsRemaining = 10800;
        });
        _timer?.cancel();
        _startTimer();
      }
      _loadBalance();
    });
  }

  @override
  Widget build(BuildContext context) {
    int h = _secondsRemaining ~/ 3600;
    int m = (_secondsRemaining % 3600) ~/ 60;
    int s = _secondsRemaining % 60;

    return Scaffold(
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
                        onTap: () => Navigator.pop(context),
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
                      'Treasure Chest',
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

            if (_secondsRemaining > 0) ...[
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
                          _buildTimeUnit(h.toString().padLeft(2, '0'), 'Hours'),
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
            ],

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _PrimaryButton(
                    text: 'Open Chest',
                    onTap: _secondsRemaining == 0 ? _openChest : null,
                  ),
                  if (_secondsRemaining > 0) ...[
                    const SizedBox(height: 16),
                    _SecondaryButton(
                      text: 'Open Instantly — Watch Ad',
                      icon: Icons.ondemand_video,
                      onTap: _openChest,
                    ),
                  ],
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
  final VoidCallback? onTap;
  const _PrimaryButton({required this.text, this.onTap});
  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _scale = 0.96) : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _scale = 1.0);
              widget.onTap!();
            }
          : null,
      onTapCancel: isEnabled ? () => setState(() => _scale = 1.0) : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: isEnabled ? AppColors.primaryGradient : null,
            color: isEnabled ? null : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.text,
            style: TextStyle(
              color: isEnabled ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Secondary Button ───
class _SecondaryButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onTap;
  const _SecondaryButton({required this.text, required this.icon, this.onTap});
  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  double _scale = 1.0;
  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _scale = 0.96) : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _scale = 1.0);
              widget.onTap!();
            }
          : null,
      onTapCancel: isEnabled ? () => setState(() => _scale = 1.0) : null,
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
                color: isEnabled
                    ? AppColors.primary.withOpacity(0.3)
                    : const Color(0xFFE2E8F0),
                width: 1.5),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.text,
                style: TextStyle(
                  color:
                      isEnabled ? AppColors.primary : const Color(0xFF94A3B8),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                widget.icon,
                color: isEnabled ? AppColors.primary : const Color(0xFF94A3B8),
                size: 20,
              ),
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
  bool _isClaiming = false;

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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFF1F5F9)),
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
                              _InteractiveCard(
                                onTap: _isClaiming
                                    ? null
                                    : () async {
                                        setState(() {
                                          _isClaiming = true;
                                        });
                                        await context
                                            .read<AppState>()
                                            .addCoins(_earnedCoins);
                                        await context
                                            .read<AppState>()
                                            .incrementGamesPlayed();
                                        if (!context.mounted) return;
                                        Navigator.of(context).pop(_earnedCoins);
                                      },
                                child: Container(
                                  width: double.infinity,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: _isClaiming
                                        ? null
                                        : AppColors.primaryGradient,
                                    color: _isClaiming
                                        ? Colors.white.withOpacity(0.5)
                                        : null,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: _isClaiming
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _isClaiming
                                        ? 'Claiming...'
                                        : 'Claim Reward',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
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
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        if (widget.onTap != null) widget.onTap!();
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
