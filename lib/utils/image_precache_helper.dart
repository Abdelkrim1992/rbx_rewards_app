import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// Pre-decodes in-app assets and critical SVGs into GPU RAM with zero-jank two-tier scheduling
class ImagePrecacheHelper {
  /// Tier 1: Fast boot precache for cold launch (limited to immediate 2-3 assets, <30ms)
  static Future<void> precacheBootAssets(BuildContext context) async {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) return;

    final futures = <Future<dynamic>>[];
    for (final asset in AppAssets.bootPrecacheAssets) {
      futures.add(
        precacheImage(
          AssetImage(asset),
          context,
          onError: (e, s) => debugPrint('Boot precache note for $asset: $e'),
        ),
      );
    }

    // Safety timeout of 350ms so startup is never delayed even on slow hardware
    await Future.wait(futures).timeout(
      const Duration(milliseconds: 350),
      onTimeout: () => [],
    );
  }

  /// Tier 2: Idle background pre-warming of navigation SVGs and dashboard cards
  static Future<void> precacheBackground(BuildContext context) async {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) return;

    final futures = <Future<dynamic>>[];

    // 1. Precompile and cache navigation SVGs
    for (final svgPath in AppAssets.allPrecacheSvgs) {
      try {
        final loader = SvgAssetLoader(svgPath);
        futures.add(loader.loadBytes(null).catchError((e) {
          debugPrint('Background SVG note for $svgPath: $e');
          return ByteData(0);
        }));
      } catch (e) {
        debugPrint('Background SVG init note for $svgPath: $e');
      }
    }

    // 2. Pre-cache secondary dashboard cards in background
    for (final asset in AppAssets.backgroundPrecacheAssets) {
      futures.add(
        precacheImage(
          AssetImage(asset),
          context,
          onError: (e, s) => debugPrint('Background asset note for $asset: $e'),
        ),
      );
    }

    await Future.wait(futures).timeout(
      const Duration(milliseconds: 4000),
      onTimeout: () => [],
    );
  }

  /// Backwards-compatible method that executes boot precache
  static Future<void> precacheAll(BuildContext context) async {
    await precacheBootAssets(context);
  }
}
