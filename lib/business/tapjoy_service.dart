import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OFFERWALL DISABLED
//
// TapjoyService is temporarily disabled to speed up builds and eliminate
// Kotlin deprecation warnings from the tapjoy_offerwall SDK.
//
// To re-enable:
//   1. Uncomment `tapjoy_offerwall: ^14.6.0` in pubspec.yaml
//   2. Run `flutter pub get`
//   3. Restore the real implementation from git history or the backup below.
// ─────────────────────────────────────────────────────────────────────────────

/// Stub implementation of TapjoyService.
/// All methods are no-ops; the real SDK is not compiled.
class TapjoyService {
  static final TapjoyService _instance = TapjoyService._internal();
  factory TapjoyService() => _instance;
  TapjoyService._internal();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Optional callback invoked when the offerwall is closed.
  VoidCallback? onClosed;

  /// No-op: SDK is disabled.
  Future<void> initialize() async {
    debugPrint('TapjoyService: ⏸ Offerwall is disabled. Skipping initialization.');
  }

  /// No-op: SDK is disabled.
  Future<void> preloadOfferwall() async {
    debugPrint('TapjoyService: ⏸ Offerwall is disabled. Skipping preload.');
  }

  /// No-op: always returns false.
  Future<bool> showOfferwall() async {
    debugPrint('TapjoyService: ⏸ Offerwall is disabled. Cannot show.');
    return false;
  }
}
