import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import 'app_image_cache_manager.dart';

/// Pre-decodes in-app assets and critical SVGs into GPU RAM for 0-millisecond rendering
class ImagePrecacheHelper {
  static Future<void> precacheAll(BuildContext context) async {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) return;

    final futures = <Future<dynamic>>[];

    // 1. Precache all critical in-app raster assets into Flutter's GPU memory cache
    for (final asset in AppAssets.allPrecacheAssets) {
      futures.add(
        precacheImage(
          AssetImage(asset),
          context,
          onError: (e, s) => debugPrint('Precache asset warning for $asset: $e'),
        ),
      );
    }

    // 2. Precompile and cache navigation SVGs
    for (final svgPath in AppAssets.allPrecacheSvgs) {
      try {
        final loader = SvgAssetLoader(svgPath);
        futures.add(loader.loadBytes(null).catchError((e) {
          debugPrint('Precache SVG warning for $svgPath: $e');
          return ByteData(0);
        }));
      } catch (e) {
        debugPrint('Precache SVG init warning for $svgPath: $e');
      }
    }

    // 3. Precache dynamic remote CDN images only if any are specified
    for (final url in AppAssets.allPrecacheNetworkImages) {
      futures.add(
        precacheImage(
          CachedNetworkImageProvider(
            url,
            cacheManager: AppImageCacheManager.instance,
          ),
          context,
          onError: (e, s) => debugPrint('Precache network warning for $url: $e'),
        ),
      );
    }

    // Await precache tasks with a graceful timeout so startup is never blocked
    await Future.wait(futures).timeout(
      const Duration(milliseconds: 3000),
      onTimeout: () => [],
    );
  }
}
