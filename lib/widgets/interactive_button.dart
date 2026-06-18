import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable interactive button with scale animation and gradient styling.
class InteractiveButton extends StatefulWidget {
  final String? text;
  final Widget? child;
  final VoidCallback? onTap;
  final bool isLoading;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? textColor;
  final BoxBorder? border;
  final double height;
  final double borderRadius;

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
    this.height = 52,
    this.borderRadius = 14,
  });

  @override
  State<InteractiveButton> createState() => _InteractiveButtonState();
}

class _InteractiveButtonState extends State<InteractiveButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null && !widget.isLoading
          ? (_) => setState(() => _scale = 0.97)
          : null,
      onTapUp: widget.onTap != null && !widget.isLoading
          ? (_) {
              setState(() => _scale = 1.0);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: widget.onTap != null
                ? (widget.gradient ?? (widget.backgroundColor == null ? AppColors.primaryGradient : null))
                : null,
            color: widget.onTap == null
                ? Colors.grey.shade400
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.border,
            boxShadow: widget.onTap != null && widget.backgroundColor == null
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: widget.textColor ?? Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : widget.child ??
                  Text(
                    widget.text ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: widget.textColor ?? Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
        ),
      ),
    );
  }
}
