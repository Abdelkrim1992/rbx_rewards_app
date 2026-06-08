import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import '../models/ad_models.dart';
import 'analytics_service.dart';

/// Manages loading, preloading, and displaying of rewarded and interstitial video ads.
class AdService {
  // Test Ad Unit IDs (Android)
  static const String _testAdUnitIdAndroid = String.fromEnvironment('TEST_AD_UNIT_ID_ANDROID');
  static const String _testInterstitialIdAndroid = String.fromEnvironment('TEST_INTERSTITIAL_ID_ANDROID');
  static const String _testRewardedInterstitialIdAndroid = String.fromEnvironment('TEST_REWARDED_INTERSTITIAL_ID_ANDROID');

  // Test Ad Unit IDs (iOS)
  static const String _testAdUnitIdIOS = String.fromEnvironment('TEST_AD_UNIT_ID_IOS');
  static const String _testInterstitialIdIOS = String.fromEnvironment('TEST_INTERSTITIAL_ID_IOS');
  static const String _testRewardedInterstitialIdIOS = String.fromEnvironment('TEST_REWARDED_INTERSTITIAL_ID_IOS');

  // Secure Android Production Keys (Injected via --dart-define-from-file=.env)
  static final String _premiumAdUnitIdAndroid = const String.fromEnvironment('PREMIUM_AD_UNIT_ID');
  static final String _quickAdUnitIdAndroid = const String.fromEnvironment('QUICK_AD_UNIT_ID');

  // Secure iOS Production Keys (Injected via --dart-define-from-file=.env)
  static final String _premiumAdUnitIdIOS = const String.fromEnvironment('PREMIUM_AD_UNIT_ID_IOS');
  static final String _quickAdUnitIdIOS = const String.fromEnvironment('QUICK_AD_UNIT_ID_IOS');

  static const int _maxPreloadedAds = 3;
  static const int _maxRetryAttempts = 5;
  static const int _frequencyCap = 3; // impressions per creative per day

  /// Multiple ad unit IDs per placement for creative rotation (Android).
  final Map<AdPlacement, List<String>> _productionAdUnitIdsAndroid = {
    AdPlacement.dailyReward: [_premiumAdUnitIdAndroid],
    AdPlacement.chestOpen: [_premiumAdUnitIdAndroid],
    AdPlacement.chestInstantUnlock: [_premiumAdUnitIdAndroid],
    AdPlacement.spinForced: [_premiumAdUnitIdAndroid],
    AdPlacement.spinExtra: [_premiumAdUnitIdAndroid],
    AdPlacement.miniGameCompletion: [_premiumAdUnitIdAndroid],
    AdPlacement.scratchCard: [_premiumAdUnitIdAndroid],
    AdPlacement.doubleReward: [_premiumAdUnitIdAndroid],
    AdPlacement.luckyBonus: [_premiumAdUnitIdAndroid],
  };

  /// Multiple ad unit IDs per placement for creative rotation (iOS).
  final Map<AdPlacement, List<String>> _productionAdUnitIdsIOS = {
    AdPlacement.dailyReward: [_premiumAdUnitIdIOS],
    AdPlacement.chestOpen: [_premiumAdUnitIdIOS],
    AdPlacement.chestInstantUnlock: [_premiumAdUnitIdIOS],
    AdPlacement.spinForced: [_premiumAdUnitIdIOS],
    AdPlacement.spinExtra: [_premiumAdUnitIdIOS],
    AdPlacement.miniGameCompletion: [_premiumAdUnitIdIOS],
    AdPlacement.scratchCard: [_premiumAdUnitIdIOS],
    AdPlacement.doubleReward: [_premiumAdUnitIdIOS],
    AdPlacement.luckyBonus: [_premiumAdUnitIdIOS],
  };

  final List<RewardedAd> _preloadedAds = [];
  final Map<AdPlacement, InterstitialAd?> _preloadedInterstitials = {};
  final Map<AdPlacement, RewardedInterstitialAd?> _preloadedRewardedInterstitials = {};
  final Map<String, int> _retryAttempts = {};
  bool _isInitialized = false;
  // Set USE_TEST_ADS=true in your .env and pass --dart-define-from-file=.env to force
  // test ads even in a release build (safe for performance testing).
  bool _developerModeEnabled =
      const bool.fromEnvironment('USE_TEST_ADS', defaultValue: false);

  /// Impressions per ad unit ID per day. Key: "placementIndex:date"
  final Map<String, int> _adUnitImpressions = {};
  String _impressionsDate = '';

  bool get isInitialized => _isInitialized;
  bool get developerModeEnabled => _developerModeEnabled;

  /// Initialize the AdMob SDK and configure COPPA settings.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      debugPrint('AdService: web detected — skipping MobileAds init');
      _isInitialized = true;
      return;
    }

    try {
      if (Platform.isIOS) {
        // Request App Tracking Transparency consent before initializing AdMob
        final trackingStatus = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (trackingStatus == TrackingStatus.notDetermined) {
          debugPrint('AdService: requesting App Tracking Transparency consent...');
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      }

      await MobileAds.instance.initialize();
      await _configureCOPPA();
      _isInitialized = true;
      debugPrint('AdService: initialized');
    } catch (e) {
      debugPrint('AdService: initialization failed: $e');
      await Future.delayed(const Duration(seconds: 30));
      return initialize();
    }
  }

  Future<void> _configureCOPPA() async {
    final requestConfiguration = RequestConfiguration(
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
      maxAdContentRating: MaxAdContentRating.g,
    );
    await MobileAds.instance.updateRequestConfiguration(requestConfiguration);
  }

  /// Toggle developer mode (always uses test ads).
  void toggleDeveloperMode() {
    _developerModeEnabled = !_developerModeEnabled;
    debugPrint('AdService: developerMode = $_developerModeEnabled');
  }

  /// Returns the appropriate ad unit ID, rotating to respect frequency caps.
  String _getAdUnitId(AdPlacement placement) {
    if (kDebugMode || _developerModeEnabled) {
      return Platform.isIOS ? _testAdUnitIdIOS : _testAdUnitIdAndroid;
    }
    final ids = Platform.isIOS
        ? _productionAdUnitIdsIOS[placement]
        : _productionAdUnitIdsAndroid[placement];
    if (ids == null || ids.isEmpty) {
      return Platform.isIOS ? _testAdUnitIdIOS : _testAdUnitIdAndroid;
    }
    if (ids.length == 1) return ids.first;

    _checkDailyReset();
    for (int i = 0; i < ids.length; i++) {
      final key = '${placement.name}_$i:$_impressionsDate';
      final count = _adUnitImpressions[key] ?? 0;
      if (count < _frequencyCap) {
        return ids[i];
      }
    }
    // All capped, return first (AdMob will handle server-side cap)
    return ids.first;
  }

  void _checkDailyReset() {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    if (_impressionsDate != today) {
      _adUnitImpressions.clear();
      _impressionsDate = today;
    }
  }

  void _recordImpression(AdPlacement placement) {
    _checkDailyReset();
    final ids = Platform.isIOS
        ? _productionAdUnitIdsIOS[placement]
        : _productionAdUnitIdsAndroid[placement];
    if (ids == null || ids.isEmpty) return;
    for (int i = 0; i < ids.length; i++) {
      if (ids[i] == _getAdUnitId(placement)) {
        final key = '${placement.name}_$i:$_impressionsDate';
        final newCount = (_adUnitImpressions[key] ?? 0) + 1;
        _adUnitImpressions[key] = newCount;
        if (newCount >= _frequencyCap) {
          AnalyticsService().logFrequencyCapping(ids[i], newCount);
        }
        break;
      }
    }
  }

  /// Load a rewarded ad for a specific placement.
  /// Returns the loaded ad or null on failure.
  Future<RewardedAd?> loadRewardedAd(AdPlacement placement) async {
    final adUnitId = _getAdUnitId(placement);
    final completer = Completer<RewardedAd?>();
    final timeout = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            timeout.cancel();
            if (!completer.isCompleted) completer.complete(ad);
          },
          onAdFailedToLoad: (error) {
            timeout.cancel();
            debugPrint(
                'AdService: failed to load ad for ${placement.name}: ${error.message}');
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
    } catch (e) {
      timeout.cancel();
      if (!completer.isCompleted) completer.complete(null);
    }

    final ad = await completer.future;
    if (ad == null) {
      await _handleAdLoadFailure(placement);
    } else {
      _retryAttempts.remove(placement.name);
    }
    return ad;
  }

  /// Retry with exponential backoff.
  Future<void> _handleAdLoadFailure(AdPlacement placement) async {
    final key = placement.name;
    final attempts = (_retryAttempts[key] ?? 0) + 1;
    _retryAttempts[key] = attempts;

    if (attempts > _maxRetryAttempts) {
      debugPrint('AdService: max retries reached for ${placement.name}');
      return;
    }

    final delay = _calculateBackoffDelay(attempts);
    debugPrint(
        'AdService: retrying ${placement.name} in ${delay.inSeconds}s (attempt $attempts)');
    await Future.delayed(delay);
    loadRewardedAd(placement);
  }

  Duration _calculateBackoffDelay(int attempt) {
    const delays = [5, 10, 20, 40, 60];
    final seconds =
        (attempt >= 1 && attempt <= delays.length) ? delays[attempt - 1] : 60;
    return Duration(seconds: seconds);
  }

  /// Show a rewarded ad and invoke [onReward] when the user earns the reward.
  Future<bool> showRewardedAd(
    RewardedAd ad, {
    AdPlacement? placement,
    required Future<void> Function(int amount) onReward,
    VoidCallback? onAdDismissed,
    Future<void> Function(AdError error)? onAdFailedToShow,
  }) async {
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('AdService: ad showed');
        if (placement != null) _recordImpression(placement);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onAdDismissed?.call();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        ad.dispose();
        await onAdFailedToShow?.call(error);
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.setImmersiveMode(true);
    ad.show(
      onUserEarnedReward: (ad, reward) async {
        final amount = reward.amount.toInt();
        await onReward(amount);
        if (!completer.isCompleted) completer.complete(true);
      },
    );

    return completer.future;
  }

  /// Preload up to [count] generic rewarded ads into the cache.
  Future<void> preloadAds(int count) async {
    final toLoad = min(count, _maxPreloadedAds - _preloadedAds.length);
    for (int i = 0; i < toLoad; i++) {
      final ad = await loadRewardedAd(AdPlacement.dailyReward);
      if (ad != null) {
        _preloadedAds.add(ad);
      }
    }
  }

  /// Preload an ad for a specific high-traffic placement.
  Future<void> preloadForPlacement(AdPlacement placement) async {
    if (_preloadedAds.length >= _maxPreloadedAds) return;
    final ad = await loadRewardedAd(placement);
    if (ad != null) {
      _preloadedAds.add(ad);
    }
  }

  /// Get a preloaded ad if available.
  RewardedAd? getPreloadedAd() {
    if (_preloadedAds.isEmpty) return null;
    return _preloadedAds.removeAt(0);
  }

  // ===== INTERSTITIAL AD METHODS =====

  /// Load an interstitial ad for a placement. Returns null on failure or web.
  Future<InterstitialAd?> loadInterstitialAd(AdPlacement placement) async {
    if (kIsWeb) return null;

    final adUnitId = _getInterstitialAdUnitId(placement);
    final completer = Completer<InterstitialAd?>();
    final timeout = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    try {
      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            timeout.cancel();
            if (!completer.isCompleted) completer.complete(ad);
          },
          onAdFailedToLoad: (error) {
            timeout.cancel();
            debugPrint(
                'AdService: interstitial failed to load for ${placement.name}: ${error.message}');
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
    } catch (e) {
      timeout.cancel();
      if (!completer.isCompleted) completer.complete(null);
    }

    return completer.future;
  }

  /// Preload an interstitial ad for a specific placement.
  Future<void> preloadInterstitial(AdPlacement placement) async {
    if (kIsWeb || _preloadedInterstitials[placement] != null) return;
    final ad = await loadInterstitialAd(placement);
    if (ad != null) {
      _preloadedInterstitials[placement] = ad;
      debugPrint('AdService: interstitial preloaded for ${placement.name}');
    }
  }

  /// Show a preloaded interstitial ad. Returns immediately if none loaded.
  /// After showing, automatically preloads the next one.
  Future<void> showInterstitial(AdPlacement placement,
      {VoidCallback? onAdDismissed}) async {
    if (kIsWeb) {
      onAdDismissed?.call();
      return;
    }

    InterstitialAd? ad = _preloadedInterstitials[placement];
    if (ad == null) {
      debugPrint('AdService: no interstitial preloaded for ${placement.name}, loading on demand...');
      ad = await loadInterstitialAd(placement);
      if (ad == null) {
        debugPrint('AdService: failed to load on demand for ${placement.name}');
        onAdDismissed?.call();
        return;
      }
    } else {
      _preloadedInterstitials[placement] = null;
    }
    final completer = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        debugPrint('AdService: interstitial showed for ${placement.name}');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
        onAdDismissed?.call();
        // Preload next interstitial in background
        preloadInterstitial(placement);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!completer.isCompleted) completer.complete();
        onAdDismissed?.call();
        preloadInterstitial(placement);
      },
    );

    // Enable immersive mode to cover the entire screen including top bar
    // This ensures no margins or padding around the ad
    await ad.setImmersiveMode(true);
    await ad.show();
    return completer.future;
  }

  String _getInterstitialAdUnitId(AdPlacement placement) {
    if (kDebugMode || _developerModeEnabled) {
      return Platform.isIOS ? _testInterstitialIdIOS : _testInterstitialIdAndroid;
    }
    final ids = Platform.isIOS
        ? _productionInterstitialIdsIOS[placement]
        : _productionInterstitialIdsAndroid[placement];
    if (ids == null || ids.isEmpty) {
      return Platform.isIOS ? _testInterstitialIdIOS : _testInterstitialIdAndroid;
    }
    return ids.first;
  }

  /// Multiple interstitial ad unit IDs per placement (Android).
  final Map<AdPlacement, List<String>> _productionInterstitialIdsAndroid = {
    AdPlacement.dailyReward: ['ca-app-pub-3940256099942544/1033173712'],
    AdPlacement.chestOpen: ['ca-app-pub-3940256099942544/1033173712'],
    AdPlacement.chestInstantUnlock: ['ca-app-pub-3940256099942544/1033173712'],
    AdPlacement.spinForced: ['ca-app-pub-3940256099942544/1033173712'],
    AdPlacement.spinExtra: ['ca-app-pub-3940256099942544/1033173712'],
    AdPlacement.miniGameCompletion: ['ca-app-pub-3940256099942544/1033173712'],
    AdPlacement.scratchCard: ['ca-app-pub-3940256099942544/1033173712'],
    AdPlacement.doubleReward: ['ca-app-pub-3940256099942544/1033173712'],
    AdPlacement.luckyBonus: ['ca-app-pub-3940256099942544/1033173712'],
  };

  /// Multiple interstitial ad unit IDs per placement (iOS).
  /// TODO: Replace placeholders with your actual iOS production Ad Unit IDs.
  final Map<AdPlacement, List<String>> _productionInterstitialIdsIOS = {
    AdPlacement.dailyReward: ['ca-app-pub-3940256099942544/4411468910'],
    AdPlacement.chestOpen: ['ca-app-pub-3940256099942544/4411468910'],
    AdPlacement.chestInstantUnlock: ['ca-app-pub-3940256099942544/4411468910'],
    AdPlacement.spinForced: ['ca-app-pub-3940256099942544/4411468910'],
    AdPlacement.spinExtra: ['ca-app-pub-3940256099942544/4411468910'],
    AdPlacement.miniGameCompletion: ['ca-app-pub-3940256099942544/4411468910'],
    AdPlacement.scratchCard: ['ca-app-pub-3940256099942544/4411468910'],
    AdPlacement.doubleReward: ['ca-app-pub-3940256099942544/4411468910'],
    AdPlacement.luckyBonus: ['ca-app-pub-3940256099942544/4411468910'],
  };

  // ===== REWARDED INTERSTITIAL AD METHODS =====

  /// Load a rewarded interstitial ad for a placement. Returns null on failure or web.
  /// Rewarded interstitials combine interstitial format with rewards - perfect for two-tier systems.
  Future<RewardedInterstitialAd?> loadRewardedInterstitialAd(AdPlacement placement) async {
    if (kIsWeb) return null;

    final adUnitId = _getRewardedInterstitialAdUnitId(placement);
    final completer = Completer<RewardedInterstitialAd?>();
    final timeout = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    try {
      await RewardedInterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            timeout.cancel();
            if (!completer.isCompleted) completer.complete(ad);
          },
          onAdFailedToLoad: (error) {
            timeout.cancel();
            debugPrint(
                'AdService: rewarded interstitial failed to load for ${placement.name}: ${error.message}');
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
    } catch (e) {
      timeout.cancel();
      if (!completer.isCompleted) completer.complete(null);
    }

    return completer.future;
  }

  /// Preload a rewarded interstitial ad for a specific placement.
  Future<void> preloadRewardedInterstitial(AdPlacement placement) async {
    if (kIsWeb || _preloadedRewardedInterstitials[placement] != null) return;
    final ad = await loadRewardedInterstitialAd(placement);
    if (ad != null) {
      _preloadedRewardedInterstitials[placement] = ad;
      debugPrint('AdService: rewarded interstitial preloaded for ${placement.name}');
    }
  }

  /// Show a rewarded interstitial ad and invoke [onReward] when the user earns the reward.
  /// This is used for the "Quick Claim" option in two-tier reward systems.
  /// Returns true if user watched and earned reward, false otherwise.
  Future<bool> showRewardedInterstitial(
    AdPlacement placement, {
    required Future<void> Function(int amount) onReward,
    VoidCallback? onAdDismissed,
    Future<void> Function(String error)? onAdFailed,
  }) async {
    if (kIsWeb) {
      await onAdFailed?.call('Ads not supported on web');
      return false;
    }

    RewardedInterstitialAd? ad = _preloadedRewardedInterstitials[placement];
    if (ad == null) {
      debugPrint('AdService: no rewarded interstitial preloaded for ${placement.name}, loading on demand...');
      ad = await loadRewardedInterstitialAd(placement);
      if (ad == null) {
        debugPrint('AdService: failed to load rewarded interstitial on demand for ${placement.name}');
        await onAdFailed?.call('Failed to load ad');
        return false;
      }
    } else {
      _preloadedRewardedInterstitials[placement] = null;
    }

    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        debugPrint('AdService: rewarded interstitial showed for ${placement.name}');
        _recordImpression(placement);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        onAdDismissed?.call();
        // Preload next rewarded interstitial in background
        preloadRewardedInterstitial(placement);
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        ad.dispose();
        await onAdFailed?.call(error.message);
        preloadRewardedInterstitial(placement);
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.setImmersiveMode(true);
    await ad.show(
      onUserEarnedReward: (ad, reward) async {
        final amount = reward.amount.toInt();
        await onReward(amount);
        if (!completer.isCompleted) completer.complete(true);
      },
    );

    return completer.future;
  }

  String _getRewardedInterstitialAdUnitId(AdPlacement placement) {
    if (kDebugMode || _developerModeEnabled) {
      return Platform.isIOS ? _testRewardedInterstitialIdIOS : _testRewardedInterstitialIdAndroid;
    }
    final ids = Platform.isIOS
        ? _productionRewardedInterstitialIdsIOS[placement]
        : _productionRewardedInterstitialIdsAndroid[placement];
    if (ids == null || ids.isEmpty) {
      return Platform.isIOS ? _testRewardedInterstitialIdIOS : _testRewardedInterstitialIdAndroid;
    }
    return ids.first;
  }

  /// Rewarded interstitial ad unit IDs per placement (Android).
  final Map<AdPlacement, List<String>> _productionRewardedInterstitialIdsAndroid = {
    AdPlacement.dailyReward: [_quickAdUnitIdAndroid],
    AdPlacement.chestOpen: [_quickAdUnitIdAndroid],
    AdPlacement.chestInstantUnlock: [_quickAdUnitIdAndroid],
    AdPlacement.spinForced: [_quickAdUnitIdAndroid],
    AdPlacement.spinExtra: [_quickAdUnitIdAndroid],
    AdPlacement.miniGameCompletion: [_quickAdUnitIdAndroid],
    AdPlacement.scratchCard: [_quickAdUnitIdAndroid],
    AdPlacement.doubleReward: [_quickAdUnitIdAndroid],
    AdPlacement.luckyBonus: [_quickAdUnitIdAndroid],
  };

  /// Rewarded interstitial ad unit IDs per placement (iOS).
  final Map<AdPlacement, List<String>> _productionRewardedInterstitialIdsIOS = {
    AdPlacement.dailyReward: [_quickAdUnitIdIOS],
    AdPlacement.chestOpen: [_quickAdUnitIdIOS],
    AdPlacement.chestInstantUnlock: [_quickAdUnitIdIOS],
    AdPlacement.spinForced: [_quickAdUnitIdIOS],
    AdPlacement.spinExtra: [_quickAdUnitIdIOS],
    AdPlacement.miniGameCompletion: [_quickAdUnitIdIOS],
    AdPlacement.scratchCard: [_quickAdUnitIdIOS],
    AdPlacement.doubleReward: [_quickAdUnitIdIOS],
    AdPlacement.luckyBonus: [_quickAdUnitIdIOS],
  };

  /// Dispose all preloaded ads.
  void dispose() {
    for (final ad in _preloadedAds) {
      ad.dispose();
    }
    _preloadedAds.clear();
    for (final ad in _preloadedInterstitials.values) {
      ad?.dispose();
    }
    _preloadedInterstitials.clear();
    for (final ad in _preloadedRewardedInterstitials.values) {
      ad?.dispose();
    }
    _preloadedRewardedInterstitials.clear();
  }
}
