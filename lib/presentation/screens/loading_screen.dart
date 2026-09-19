import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../utils/image_precache_helper.dart';
import '../../widgets/circular_gradient_spinner.dart';

/// The cold boot splash screen that displays the app boot icon and circular gradient loader.
/// Provides seamless visual continuity from native launch splash until services and critical
/// assets are initialized and transitioned to the Flutter UI.
class LoadingScreen extends StatefulWidget {
  final Future<ProviderContainer> Function()? onBootstrap;
  final ValueChanged<ProviderContainer>? onReady;

  const LoadingScreen({
    super.key,
    this.onBootstrap,
    this.onReady,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  bool _isBootstrapping = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.028).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: Curves.easeInOutSine,
      ),
    );

    final isTestEnvironment =
        (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) ||
            WidgetsBinding.instance.runtimeType.toString().contains('Test');

    if (!isTestEnvironment) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.value = 0.5;
    }

    if (widget.onBootstrap != null && widget.onReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runColdBootSequence();
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _runColdBootSequence() async {
    if (_isBootstrapping) return;
    _isBootstrapping = true;

    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      try {
        final container = await widget.onBootstrap!();
        if (mounted) widget.onReady?.call(container);
      } catch (e) {
        debugPrint('Cold boot test bootstrap error: $e');
        if (mounted) widget.onReady?.call(ProviderContainer());
      }
      return;
    }

    try {
      // 1. Kick off service bootstrap (Supabase, Hive, SharedPreferences)
      final bootstrapFuture = widget.onBootstrap!();

      // 2. Fast boot precache for cold launch (limited to immediate 2-3 assets, <30ms)
      final precacheFuture = ImagePrecacheHelper.precacheBootAssets(context);

      // 3. Ultra-short frame-smoothing duration (200ms) to prevent visual flash
      final minDurationFuture =
          Future.delayed(const Duration(milliseconds: 200));

      final results = await Future.wait([
        bootstrapFuture,
        precacheFuture,
        minDurationFuture,
      ]).timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {
          debugPrint('⚠️ Cold boot sequence timeout reached (1500ms), proceeding immediately...');
          return [ProviderContainer(), null, null];
        },
      );

      final container = results[0] as ProviderContainer;

      if (mounted) {
        widget.onReady?.call(container);
      }
    } catch (e) {
      debugPrint('❌ Cold boot sequence error: $e');
      if (mounted) {
        widget.onReady?.call(ProviderContainer());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hero 3D boot icon with subtle breathing micro-animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: Image.asset(
                  AppAssets.appIcon,
                  width: 128,
                  height: 128,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 38),
              // Circular gradient spinner matching user reference
              const CircularGradientSpinner(
                size: 46.0,
                strokeWidth: 3.8,
                label: 'Loading...',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
