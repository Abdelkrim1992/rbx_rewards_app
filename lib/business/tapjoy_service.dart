import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tapjoy_offerwall/tapjoy_offerwall.dart';

/// Manages Tapjoy SDK initialization, placement caching, and display.
class TapjoyService {
  static final TapjoyService _instance = TapjoyService._internal();
  factory TapjoyService() => _instance;
  TapjoyService._internal();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  TJPlacement? _offerwallPlacement;
  bool _isPlacementLoading = false;

  /// Connects to Tapjoy SDK using configuration variables.
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('TapjoyService: web platform - Tapjoy SDK is not supported.');
      return;
    }

    final String sdkKey = Platform.isIOS
        ? const String.fromEnvironment('TAPJOY_SDK_KEY_IOS', defaultValue: 'test_ios_sdk_key')
        : const String.fromEnvironment('TAPJOY_SDK_KEY_ANDROID', defaultValue: 'test_android_sdk_key');

    if (sdkKey == 'test_ios_sdk_key' || sdkKey == 'test_android_sdk_key') {
      debugPrint('⚠️ TapjoyService: Using mock placeholder keys. Pass real keys via --dart-define in production.');
    }

    final Map<String, dynamic> optionFlags = {};

    try {
      debugPrint('TapjoyService: Connecting to Tapjoy...');
      await Tapjoy.connect(
        sdkKey: sdkKey,
        options: optionFlags,
        onConnectSuccess: () async {
          _isConnected = true;
          debugPrint('TapjoyService: Successfully connected to Tapjoy SDK.');
          await Tapjoy.setLoggingLevel(TJLoggingLevel.debug);
          await preloadOfferwall();
        },
        onConnectFailure: (int code, String? error) async {
          _isConnected = false;
          debugPrint('TapjoyService: Failed to connect (code: $code): $error');
        },
        onConnectWarning: (int code, String? warning) async {
          debugPrint('TapjoyService: Connection warning (code: $code): $warning');
        },
      );
    } catch (e) {
      debugPrint('TapjoyService: Error during connection process: $e');
    }
  }

  /// Preload the Offerwall placement from Tapjoy servers.
  Future<void> preloadOfferwall() async {
    if (!_isConnected) {
      debugPrint('TapjoyService: Cannot preload placement - SDK is not connected.');
      return;
    }

    if (_isPlacementLoading) return;

    _isPlacementLoading = true;
    try {
      const placementName = String.fromEnvironment('TAPJOY_PLACEMENT_NAME', defaultValue: 'Offerwall');
      debugPrint('TapjoyService: Requesting placement content for "$placementName"...');

      _offerwallPlacement = await TJPlacement.getPlacement(
        placementName: placementName,
        onRequestSuccess: (placement) {
          debugPrint('TapjoyService: TJPlacement onRequestSuccess');
        },
        onRequestFailure: (placement, error) {
          debugPrint('TapjoyService: TJPlacement onRequestFailure: $error');
        },
        onContentReady: (placement) {
          debugPrint('TapjoyService: TJPlacement onContentReady');
        },
        onContentShow: (placement) {
          debugPrint('TapjoyService: TJPlacement onContentShow');
        },
        onContentDismiss: (placement) {
          debugPrint('TapjoyService: TJPlacement onContentDismiss. Auto-preloading next content...');
          placement.requestContent().catchError((err) {
            debugPrint('TapjoyService: Error preloading placement after dismiss: $err');
          });
        },
      );
      await _offerwallPlacement?.requestContent();
      debugPrint('TapjoyService: Content requested.');
    } catch (e) {
      debugPrint('TapjoyService: Failed to create or load placement: $e');
    } finally {
      _isPlacementLoading = false;
    }
  }

  /// Checks if placement is ready and displays the Tapjoy Offerwall.
  Future<bool> showOfferwall() async {
    if (!_isConnected) {
      debugPrint('TapjoyService: Cannot show offerwall - SDK is not connected.');
      await initialize();
      return false;
    }

    try {
      final placement = _offerwallPlacement;
      if (placement == null) {
        debugPrint('TapjoyService: Placement was not preloaded. Retrying preload...');
        await preloadOfferwall();
        return false;
      }

      final isReady = await placement.isContentReady();
      if (isReady == true) {
        debugPrint('TapjoyService: Showing Tapjoy Offerwall content.');
        await placement.showContent();
        return true;
      } else {
        debugPrint('TapjoyService: Offerwall content not ready yet. Re-requesting...');
        await placement.requestContent();
        return false;
      }
    } catch (e) {
      debugPrint('TapjoyService: Failed to show Tapjoy Offerwall: $e');
      return false;
    }
  }
}
