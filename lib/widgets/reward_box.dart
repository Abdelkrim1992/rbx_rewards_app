import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable Reward Box component matching the screenshot reward popup design.
///
/// Features:
/// - Wide full-width card with soft lavender border (`0xFFE8E5FA`)
/// - Centered gold RBX coin asset (`AppAssets.goldRbxCoin`)
/// - Bold typography `+X RBX` in signature primary purple
/// - Supports live odometer [animation] and [isDoubled] state styling
class RewardBox extends StatelessWidget {
  final int amount;
  final Animation<int>? animation;
  final bool isDoubled;
  final double? width;
  final double height;
  final double coinSize;
  final double fontSize;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final Color? backgroundColor;

  const RewardBox({
    super.key,
    required this.amount,
    this.animation,
    this.isDoubled = false,
    this.width = double.infinity,
    this.height = 64,
    this.coinSize = 34,
    this.fontSize = 28,
    this.padding,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeBorderColor = borderColor ??
        (isDoubled ? const Color(0xFF8C62F8) : const Color(0xFFE8E5FA));
    final activeBgColor = backgroundColor ??
        (isDoubled ? const Color(0xFFFBF9FF) : Colors.white);

    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: activeBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activeBorderColor,
          width: 1.5,
        ),
        boxShadow: isDoubled
            ? const [
                BoxShadow(
                  color: Color(0x2E6035EE),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AppAssets.goldRbxCoin,
              width: coinSize,
              height: coinSize,
              errorBuilder: (_, __, ___) => Icon(
                Icons.monetization_on,
                color: const Color(0xFFFFB000),
                size: coinSize,
              ),
            ),
            const SizedBox(width: 10),
            if (animation != null)
              AnimatedBuilder(
                animation: animation!,
                builder: (context, _) {
                  return Text(
                    '+${animation!.value} RBX',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: isDoubled
                          ? const Color(0xFF8C62F8)
                          : AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  );
                },
              )
            else
              Text(
                '+$amount RBX',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: isDoubled
                      ? const Color(0xFF8C62F8)
                      : AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
