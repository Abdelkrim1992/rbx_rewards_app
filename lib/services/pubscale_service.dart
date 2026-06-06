import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pubscale_offerwall_plugin/pubscale_offerwall_plugin.dart';

/// Manages PubScale Offerwall SDK initialization, event tracking, and display.
class PubscaleService {
  static final PubscaleService _instance = PubscaleService._internal();
  factory PubscaleService() => _instance;
  PubscaleService._internal();

  final _plugin = PubscaleOfferwallPlugin();
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initializes the PubScale Offerwall SDK for the authenticated user.
  Future<void> initialize(String userId) async {
    if (kIsWeb) {
      debugPrint('PubscaleService: web platform - PubScale SDK is not supported.');
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('PubscaleService: ${Platform.operatingSystem} platform - PubScale SDK is not supported.');
      return;
    }

    if (_isInitialized) return;

    const appId = String.fromEnvironment('PUBSCALE_APP_ID', defaultValue: 'test_pubscale_app_id');
    const sandboxStr = String.fromEnvironment('PUBSCALE_SANDBOX', defaultValue: 'true');
    final isSandbox = sandboxStr.toLowerCase() == 'true';
    
    if (appId == 'test_pubscale_app_id') {
      debugPrint('⚠️ PubscaleService: Using mock placeholder App ID. Pass real ID via --dart-define in production.');
    }
    debugPrint('PubscaleService: Sandbox mode is set to $isSandbox.');

    try {
      debugPrint('PubscaleService: Initializing for user $userId (App ID: $appId)...');

      // Listen to Offerwall events
      _plugin.offerwallEvents.listen(
        (event) {
          final String? eventName = event['event']?.toString();
          debugPrint('PubScale SDK Event: $eventName');

          if (eventName == 'offerwall_init_success') {
            _isInitialized = true;
            debugPrint('PubscaleService: SDK successfully initialized.');
          } else if (eventName == 'offerwall_init_failed') {
            _isInitialized = false;
            final error = event['error']?.toString() ?? 'Unknown initialization error';
            debugPrint('PubscaleService: SDK initialization failed: $error');
          } else if (eventName == 'offerwall_showed') {
            debugPrint('PubscaleService: Offerwall successfully shown.');
          } else if (eventName == 'offerwall_launch_failed') {
            final error = event['error']?.toString() ?? 'Unknown launch error';
            debugPrint('PubscaleService: Offerwall launch failed: $error');
          } else if (eventName == 'offerwall_closed') {
            debugPrint('PubscaleService: Offerwall closed.');
          } else if (eventName == 'offerwall_reward') {
            final amount = event['amount'];
            final currency = event['currency'];
            debugPrint('PubscaleService: Reward received client-side: $amount $currency');
          }
        },
        onError: (err) {
          debugPrint('PubscaleService: Event stream error: $err');
        },
      );

      // Call initialize on the plugin
      await _plugin.initializeOfferwall(
        appId,
        userId,
        isSandbox, // configurable sandbox mode
        true, // fullscreen: true
      );
      debugPrint('PubscaleService: Initialization request sent.');
    } catch (e) {
      debugPrint('PubscaleService: Error during initialization process: $e');
    }
  }

  /// Launches/displays the PubScale Offerwall on the screen.
  Future<bool> launch() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('PubscaleService: Launch not supported on this platform.');
      return false;
    }

    try {
      debugPrint('PubscaleService: Requesting to launch Offerwall...');
      await _plugin.launchOfferwall();
      return true;
    } catch (e) {
      debugPrint('PubscaleService: Failed to launch PubScale Offerwall: $e');
      return false;
    }
  }
}
