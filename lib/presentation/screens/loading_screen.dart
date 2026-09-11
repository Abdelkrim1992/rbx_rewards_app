import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../utils/image_precache_helper.dart';
import '../../widgets/circular_gradient_spinner.dart';

/// The cold boot splash screen that displays the app logo and circular gradient loader.
/// Stays visible until services are initialized and all app images are fully precached into GPU memory.
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

class _LoadingScreenState extends State<LoadingScreen> {
  bool _isBootstrapping = false;

  @override
  void initState() {
    super.initState();
    if (widget.onBootstrap != null && widget.onReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runColdBootSequence();
      });
    }
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

    final stopwatch = Stopwatch()..start();

    try {
      // 1. Kick off service bootstrap (Supabase, Hive, SharedPreferences, Auth)
      final bootstrapFuture = widget.onBootstrap!();

      // 2. Concurrently precache all raster images, navigation SVGs, and network assets
      final precacheFuture = ImagePrecacheHelper.precacheAll(context);

      // 3. Await both tasks
      final results = await Future.wait([
        bootstrapFuture,
        precacheFuture,
      ]).timeout(
        const Duration(seconds: 6),
        onTimeout: () async {
          debugPrint('⚠️ Cold boot sequence timeout reached, continuing...');
          final container = await bootstrapFuture.catchError((_) => ProviderContainer());
          return [container, null];
        },
      );

      final container = results[0] as ProviderContainer;

      // 4. Ensure a minimum smooth display duration (1600ms) so user sees boot screen and loader
      final elapsedMs = stopwatch.elapsedMilliseconds;
      const minDisplayMs = 1600;
      if (elapsedMs < minDisplayMs) {
        await Future.delayed(Duration(milliseconds: minDisplayMs - elapsedMs));
      }

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
              // High-definition RBX brand logo
              Image.asset(
                AppAssets.rbxLogo,
                width: 220,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => Image.asset(
                  AppAssets.bootImage,
                  width: 110,
                  height: 110,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
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
