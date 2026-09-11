import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Persistent local storage disk cache manager for app images.
///
/// Features:
/// - Persists images on local device storage across app launches.
/// - 90-day stale period (images are kept locally for 3 months after first fetch).
/// - High capacity (up to 300 objects cached simultaneously).
/// - Instant 0-millisecond offline loading on subsequent app launches.
class AppImageCacheManager {
  static const String key = 'rbx_app_image_cache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 300,
      fileService: HttpFileService(),
    ),
  );
}
