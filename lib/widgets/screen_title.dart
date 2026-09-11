import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable section title bar for main menu screens with title, subtitle,
/// and an optional right-aligned pill action button.
class RbxScreenTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionText;
  final IconData? actionIcon;
  final VoidCallback? onActionTap;
  final Widget? customAction;
  final EdgeInsetsGeometry? padding;

  const RbxScreenTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.actionIcon,
    this.onActionTap,
    this.customAction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.only(
            left: AppLayout.screenPadding,
            right: AppLayout.screenPadding,
            top: 5,
            bottom: 12,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF131326),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF868A9F),
                  ),
                ),
              ],
            ),
          ),
          if (customAction != null)
            customAction!
          else if (actionText != null && onActionTap != null)
            GestureDetector(
              onTap: onActionTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionIcon != null) ...[
                      Icon(
                        actionIcon,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      actionText!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
