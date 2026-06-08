import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pubscale_offerwall_plugin/pubscale_offerwall_plugin.dart';

/// Manages PubScale Offerwall SDK initialization, event tracking, and display.
///
/// Usage:
///   1. Call [initialize] once at startup with the user's ID (done in main.dart).
///   2. Optionally set [onReward] to handle coins/currency earned from the offerwall.
///   3. Call [launch] from any screen to display the offerwall.
class PubscaleService {
  static final PubscaleService _instance = PubscaleService._internal();
  factory PubscaleService() => _instance;
  PubscaleService._internal();

  final _plugin = PubscaleOfferwallPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  StreamSubscription? _eventSubscription;

  /// Optional callback invoked when the user earns a reward from the offerwall.
  /// Parameters: amount (int), currency (String)
  void Function(int amount, String currency)? onReward;

  /// Initializes the PubScale Offerwall SDK for the authenticated user.
  /// Call this once at app startup (see main.dart).
  Future<void> initialize(String userId) async {
    if (kIsWeb) {
      debugPrint('PubscaleService: web platform — PubScale SDK not supported.');
      return;
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('PubscaleService: ${Platform.operatingSystem} — PubScale SDK not supported.');
      return;
    }
    if (_isInitialized) return;

    // App Key from PubScale dashboard (NOT the numeric App ID).
    // Pass via --dart-define-from-file=.env at build time.
    const appKey = String.fromEnvironment('PUBSCALE_APP_ID', defaultValue: '');
    // Sandbox mode: set PUBSCALE_SANDBOX=true in .env for testing.
    const sandboxStr = String.fromEnvironment('PUBSCALE_SANDBOX', defaultValue: 'false');
    final isSandbox = sandboxStr.toLowerCase() == 'true';

    if (appKey.isEmpty) {
      debugPrint('⚠️ PubscaleService: PUBSCALE_APP_ID is not set. Pass it via --dart-define-from-file=.env.');
      return;
    }

    debugPrint('PubscaleService: Initializing for user "$userId" | sandbox=$isSandbox');

    // Cancel any previous subscription before re-subscribing
    await _eventSubscription?.cancel();
    _eventSubscription = _plugin.offerwallEvents.listen(
      (event) {
        final String? eventName = event['event']?.toString();
        debugPrint('PubscaleService event: $eventName | $event');

        switch (eventName) {
          case 'offerwall_init_success':
            _isInitialized = true;
            debugPrint('PubscaleService: ✅ SDK initialized successfully.');
            break;

          case 'offerwall_init_failed':
            _isInitialized = false;
            final error = event['error']?.toString() ?? 'Unknown error';
            debugPrint('PubscaleService: ❌ SDK init failed: $error');
            break;

          case 'offerwall_showed':
            debugPrint('PubscaleService: Offerwall shown.');
            break;

          case 'offerwall_closed':
            debugPrint('PubscaleService: Offerwall closed.');
            break;

          case 'offerwall_reward':
            final amount = (event['amount'] as num?)?.toInt() ?? 0;
            final currency = event['currency']?.toString() ?? '';
            debugPrint('PubscaleService: 🎉 Reward earned: $amount $currency');
            onReward?.call(amount, currency);
            break;

          case 'offerwall_launch_failed':
            final error = event['error']?.toString() ?? 'Unknown error';
            debugPrint('PubscaleService: ❌ Launch failed: $error');
            break;
        }
      },
      onError: (err) {
        debugPrint('PubscaleService: Event stream error: $err');
      },
    );

    try {
      await _plugin.initializeOfferwall(
        appKey,   // PubScale App Key
        userId,   // Unique user ID
        isSandbox, // sandbox mode — set true in .env for testing
        true,    // fullscreen — false shows as a modal overlay
      );
      debugPrint('PubscaleService: Initialization request sent — waiting for offerwall_init_success event.');
    } catch (e) {
      debugPrint('PubscaleService: Exception during initializeOfferwall(): $e');
    }
  }

  /// Launches/displays the PubScale Offerwall on the screen.
  /// Returns true if launch was requested successfully, false otherwise.
  Future<bool> launch() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('PubscaleService: Platform not supported for launch.');
      return false;
    }

    if (!_isInitialized) {
      debugPrint('PubscaleService: ⚠️ Not yet initialized — offerwall_init_success has not fired yet. '
          'Make sure PubscaleService().initialize(userId) is called at startup and the SDK has connected.');
      return false;
    }

    try {
      debugPrint('PubscaleService: Launching offerwall...');
      await _plugin.launchOfferwall();
      return true;
    } catch (e) {
      debugPrint('PubscaleService: Exception during launchOfferwall(): $e');
      return false;
    }
  }

  /// Dispose event subscription. Call if the service is torn down.
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }
}
