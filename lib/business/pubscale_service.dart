import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OFFERWALL DISABLED
//
// PubscaleService is temporarily disabled to speed up builds and eliminate
// Kotlin warnings from the pubscale_offerwall_plugin SDK.
//
// To re-enable:
//   1. Uncomment `pubscale_offerwall_plugin: ^0.0.4` in pubspec.yaml
//   2. Run `flutter pub get`
//   3. Restore the real implementation from git history or the backup below.
// ─────────────────────────────────────────────────────────────────────────────

/// Stub implementation of PubscaleService.
/// All methods are no-ops; the real SDK is not compiled.
class PubscaleService {
  static final PubscaleService _instance = PubscaleService._internal();
  factory PubscaleService() => _instance;
  PubscaleService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Optional callback invoked when the user earns a reward from the offerwall.
  /// Parameters: amount (int), currency (String)
  void Function(int amount, String currency)? onReward;

  /// No-op: SDK is disabled.
  Future<void> initialize(String userId) async {
    debugPrint('PubscaleService: ⏸ Offerwall is disabled. Skipping initialization.');
  }

  /// No-op: always returns false.
  Future<bool> launch() async {
    debugPrint('PubscaleService: ⏸ Offerwall is disabled. Cannot launch.');
    return false;
  }

  /// No-op.
  Future<void> dispose() async {}
}
