import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// Pre-decodes in-app assets and remote UI assets into GPU RAM and local disk storage
class ImagePrecacheHelper {
  static Future<void> precacheAll(BuildContext context) async {
    final futures = <Future<dynamic>>[];

    // 1. Precache all in-app raster assets into Flutter's GPU memory cache
    for (final asset in AppAssets.allPrecacheAssets) {
      futures.add(
        precacheImage(AssetImage(asset), context).catchError((e) {
          debugPrint('Precache asset warning for $asset: $e');
        }),
      );
    }

    // 2. Precache & disk-cache remote UI icons locally
    for (final url in AppAssets.allPrecacheNetworkImages) {
      futures.add(
        precacheImage(CachedNetworkImageProvider(url), context).catchError((e) {
          debugPrint('Precache network image warning for $url: $e');
        }),
      );
    }

    // 3. Precompile and cache navigation SVGs
    for (final svgPath in AppAssets.allPrecacheSvgs) {
      try {
        final loader = SvgAssetLoader(svgPath);
        futures.add(loader.loadBytes(null).catchError((e) {
          debugPrint('Precache SVG warning for $svgPath: $e');
          return Uint8List(0);
        }));
      } catch (e) {
        debugPrint('Precache SVG init warning for $svgPath: $e');
      }
    }

    // Await all precache tasks with a max timeout so app launch is never blocked
    await Future.wait(futures).timeout(
      const Duration(milliseconds: 2000),
      onTimeout: () => [],
    );
  }
}
