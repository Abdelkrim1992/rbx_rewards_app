import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Celebration dialog shown after a rewarded ad completes.
class AdRewardSuccessDialog extends StatefulWidget {
  final int earnedAmount;

  const AdRewardSuccessDialog({super.key, required this.earnedAmount});

  @override
  State<AdRewardSuccessDialog> createState() => _AdRewardSuccessDialogState();

  static Future<void> show(BuildContext context, {required int amount}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AdRewardSuccessDialog(earnedAmount: amount),
    );
  }
}

class _AdRewardSuccessDialogState extends State<AdRewardSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Timer? _autoDismissTimer;

  final _messages = [
    'Awesome! You earned {} coins! 🎉',
    'Great job! {} coins added! 💰',
    'Amazing! You got {} coins! ⭐',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();

    _autoDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _messages[Random().nextInt(_messages.length)]
        .replaceAll('{}', widget.earnedAmount.toString());

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D2D),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  '+${widget.earnedAmount}',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap to dismiss',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
