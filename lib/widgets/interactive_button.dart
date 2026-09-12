import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable interactive button with tactile scale animation,
/// primaryGradient purple styling, rounded pill/card border radius,
/// and soft glowing drop shadow matching the app's brand standard.
class InteractiveButton extends StatefulWidget {
  final String? text;
  final Widget? child;
  final VoidCallback? onTap;
  final bool isLoading;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? textColor;
  final BoxBorder? border;
  final double? width;
  final double height;
  final double borderRadius;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsetsGeometry? padding;
  final IconData? icon;
  final double iconSize;
  final double iconSpacing;

  const InteractiveButton({
    super.key,
    this.text,
    this.child,
    this.onTap,
    this.isLoading = false,
    this.gradient,
    this.backgroundColor,
    this.textColor,
    this.border,
    this.width,
    this.height = 54,
    this.borderRadius = 16,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w700,
    this.padding,
    this.icon,
    this.iconSize = 18,
    this.iconSpacing = 8,
    Color? color,
  });

  @override
  State<InteractiveButton> createState() => _InteractiveButtonState();
}

class _InteractiveButtonState extends State<InteractiveButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onTap != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _scale = 0.96) : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _scale = 1.0);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: isEnabled ? () => setState(() => _scale = 1.0) : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            gradient: isEnabled
                ? (widget.gradient ??
                    (widget.backgroundColor == null
                        ? AppColors.primaryGradient
                        : null))
                : null,
            color: isEnabled
                ? widget.backgroundColor
                : (widget.backgroundColor != null
                    ? widget.backgroundColor!.withValues(alpha: 0.5)
                    : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.border,
            boxShadow: isEnabled && widget.backgroundColor == null
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: widget.textColor ?? Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : widget.child ??
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: widget.iconSize,
                          color: isEnabled
                              ? (widget.textColor ?? Colors.white)
                              : const Color(0xFF94A3B8),
                        ),
                        SizedBox(width: widget.iconSpacing),
                      ],
                      if (widget.text != null)
                        Text(
                          widget.text!,
                          style: TextStyle(
                            fontSize: widget.fontSize,
                            fontWeight: widget.fontWeight,
                            color: isEnabled
                                ? (widget.textColor ?? Colors.white)
                                : const Color(0xFF94A3B8),
                            letterSpacing: 0.2,
                          ),
                        ),
                    ],
                  ),
        ),
      ),
    );
  }
}
