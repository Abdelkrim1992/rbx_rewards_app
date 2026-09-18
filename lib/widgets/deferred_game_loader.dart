import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'circular_gradient_spinner.dart';

/// Production-grade deferred component loader for RBX mini-games.
/// Ensures heavy game logic and game engines (Flame, Scratcher) are only
/// compiled and loaded into memory when the user actually launches the game.
class DeferredGameLoader extends StatefulWidget {
  final Future<void> Function() loadLibrary;
  final Widget Function() builder;
  final String title;
  final Color themeColor;
  final String? iconAsset;

  const DeferredGameLoader({
    super.key,
    required this.loadLibrary,
    required this.builder,
    required this.title,
    this.themeColor = AppColors.primary,
    this.iconAsset,
  });

  @override
  State<DeferredGameLoader> createState() => _DeferredGameLoaderState();
}

class _DeferredGameLoaderState extends State<DeferredGameLoader> {
  bool _isLoaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await widget.loadLibrary();
      if (mounted) {
        setState(() {
          _isLoaded = true;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded) {
      return widget.builder();
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            widget.title,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 54,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 16),
                Text(
                  'Could not load ${widget.title}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _load();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.iconAsset != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    widget.iconAsset!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              CircularGradientSpinner(
                size: 42.0,
                strokeWidth: 3.5,
                label: 'Loading ${widget.title}...',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
