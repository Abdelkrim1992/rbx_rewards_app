import 'dart:async';
import 'package:flutter/material.dart';

/// Animated loading dialog shown while an ad is being loaded.
class AdLoadingDialog extends StatefulWidget {
  final VoidCallback? onSkip;

  const AdLoadingDialog({super.key, this.onSkip});

  @override
  State<AdLoadingDialog> createState() => _AdLoadingDialogState();

  /// Show the dialog and return a future that completes when dismissed.
  static Future<void> show(BuildContext context, {VoidCallback? onSkip}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdLoadingDialog(onSkip: onSkip),
    );
  }
}

class _AdLoadingDialogState extends State<AdLoadingDialog>
    with TickerProviderStateMixin {
  int _elapsedSeconds = 0;
  bool _showTakingLonger = false;
  bool _showSkip = false;
  Timer? _timer;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds++;
        if (_elapsedSeconds >= 5) _showTakingLonger = true;
        if (_elapsedSeconds >= 10) _showSkip = true;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1D2D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _bounceController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -4 * _bounceController.value),
                  child: const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFD4AF37),
                    size: 48,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading ad...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_elapsedSeconds}s',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (_showTakingLonger) ...[
              const SizedBox(height: 12),
              const Text(
                'This is taking longer than usual...',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
            if (_showSkip && widget.onSkip != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  widget.onSkip?.call();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Color(0xFF6B46C1)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
