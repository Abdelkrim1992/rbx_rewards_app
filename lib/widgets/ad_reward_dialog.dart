import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'interactive_button.dart';

/// Simulated rewarded video ad dialog.
/// Shows a 5-second countdown with progress bar, then calls [onRewardGranted].
class AdRewardDialog extends StatefulWidget {
  final FutureOr<void> Function() onRewardGranted;
  final String? title;
  final String? subtitle;
  final String? buttonText;

  const AdRewardDialog({
    super.key,
    required this.onRewardGranted,
    this.title,
    this.subtitle,
    this.buttonText,
  });

  @override
  State<AdRewardDialog> createState() => _AdRewardDialogState();
}

class _AdRewardDialogState extends State<AdRewardDialog> {
  double _progress = 0.0;
  int _secondsLeft = 5;
  bool _adFinished = false;
  bool _isClaiming = false;
  Timer? _timer;
  final int _particleSeed = Random().nextInt(1000);

  @override
  void initState() {
    super.initState();
    _startAdTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAdTimer() {
    const totalMs = 5000;
    const intervalMs = 50;
    int elapsedMs = 0;

    _timer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      elapsedMs += intervalMs;
      setState(() {
        _progress = (elapsedMs / totalMs).clamp(0.0, 1.0);
        _secondsLeft = (5 - (elapsedMs ~/ 1000)).clamp(0, 5);
      });

      if (elapsedMs >= totalMs) {
        timer.cancel();
        setState(() {
          _adFinished = true;
        });
        HapticFeedback.heavyImpact();
      }
    });
  }

  Future<void> _claim() async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);
    try {
      await widget.onRewardGranted();
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final isCompact = screenWidth < 360;
    final isShort = screenHeight < 680;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 24,
        vertical: isCompact ? 16 : 24,
      ),
      child: Container(
        width: min(screenWidth - (isCompact ? 32.0 : 48.0), 400.0),
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.92,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isCompact ? 18.0 : 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.title ?? 'REWARDED AD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _adFinished ? 'Finished' : 'Reward in ${_secondsLeft}s...',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFB000),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 14 : 20),

              // Ad simulation screen
              Container(
                width: double.infinity,
                height: isShort ? 140 : 180,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Decorative animated dots
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CustomPaint(
                          painter: _AdParticlesPainter(
                            _particleSeed,
                            _progress,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _adFinished ? Icons.card_giftcard : Icons.play_circle,
                          color: Colors.white,
                          size: isShort ? 44 : 60,
                        ),
                        SizedBox(height: isShort ? 8 : 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _adFinished
                                  ? (widget.subtitle ?? 'Ad Completed! 2x Coins Unlocked')
                                  : 'Watching premium video ad...',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: isCompact ? 14 : 20),

              // Progress bar
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 16 : 24),

              // Claim action button
              InteractiveButton(
                height: isCompact ? 48 : 54,
                text: _adFinished
                    ? (widget.buttonText ?? 'CLAIM 2x REWARD')
                    : 'WATCHING AD...',
                onTap: _adFinished ? _claim : null,
                gradient: _adFinished ? AppColors.primaryGradient : null,
                backgroundColor: _adFinished ? null : const Color(0xFFE2E2F5),
                textColor: _adFinished ? Colors.white : const Color(0xFF868A9F),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Particle painter for ad background ──
class _AdParticlesPainter extends CustomPainter {
  final int seed;
  final double progress;

  _AdParticlesPainter(this.seed, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final double r = 2.0 + random.nextDouble() * 4;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AdParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.seed != seed;
}
