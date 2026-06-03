import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/ad_models.dart';
import '../services/ad_service.dart';
import '../services/ad_tracker_service.dart';
import '../services/badge_service.dart';
import '../services/daily_cap_service.dart';
import '../models/badge_model.dart';

/// Reactive state holder for ad system.
class AdState extends ChangeNotifier {
  final AdService _adService;
  final AdTrackerService _trackerService;
  final BadgeService _badgeService;
  final DailyCapService _dailyCapService;

  final Map<AdPlacement, AdLoadStatus> _adLoadStatuses = {};
  final Map<AdPlacement, RewardedAd?> _preloadedAds = {};
  bool _isInitialized = false;
  bool _isShowingAd = false;
  List<Badge> _newlyEarnedBadges = [];

  AdState({
    required AdService adService,
    required AdTrackerService trackerService,
    BadgeService? badgeService,
    DailyCapService? dailyCapService,
  })  : _adService = adService,
        _trackerService = trackerService,
        _badgeService = badgeService ?? BadgeService(),
        _dailyCapService = dailyCapService ?? DailyCapService();

  bool get isInitialized => _isInitialized;
  bool get isShowingAd => _isShowingAd;
  AdTrackingData get trackingData => _trackerService.trackingData;

  int get dailyAdsWatched => _trackerService.dailyAdsWatched;
  int get remainingForcedAds => _trackerService.getRemainingForcedAds();
  int get remainingOptionalAds => _trackerService.getRemainingOptionalAds();
  bool get canShowForcedAd => _trackerService.canShowForcedAd();
  bool get canShowOptionalAd => _trackerService.canShowOptionalAd();

  AdLoadStatus statusFor(AdPlacement placement) =>
      _adLoadStatuses[placement] ?? AdLoadStatus.notLoaded;

  /// Initialize the ad system.
  Future<void> initialize() async {
    await _adService.initialize();
    await _trackerService.load();
    await _badgeService.load();
    await _dailyCapService.load();
    await _adService.preloadAds(2);
    // Preload interstitials for all high-traffic placements
    await _adService.preloadInterstitial(AdPlacement.dailyReward);
    await _adService.preloadInterstitial(AdPlacement.chestOpen);
    await _adService.preloadInterstitial(AdPlacement.chestInstantUnlock);
    await _adService.preloadInterstitial(AdPlacement.spinForced);
    await _adService.preloadInterstitial(AdPlacement.spinExtra);
    await _adService.preloadInterstitial(AdPlacement.scratchCard);
    // Preload rewarded interstitials for two-tier reward system
    await _adService.preloadRewardedInterstitial(AdPlacement.dailyReward);
    await _adService.preloadRewardedInterstitial(AdPlacement.chestOpen);
    await _adService.preloadRewardedInterstitial(AdPlacement.miniGameCompletion);
    await _adService.preloadRewardedInterstitial(AdPlacement.scratchCard);
    await _adService.preloadRewardedInterstitial(AdPlacement.doubleReward);
    _isInitialized = true;
    notifyListeners();
  }

  List<Badge> get newlyEarnedBadges => List.unmodifiable(_newlyEarnedBadges);
  int get dailyEarningsRemaining => _dailyCapService.remainingToday;
  bool get isDailyCapReached => _dailyCapService.isCapReached;
  BadgeService get badgeService => _badgeService;

  void clearNewBadges() {
    _newlyEarnedBadges = [];
    notifyListeners();
  }

  void recordOptionalAdWatched() {
    _trackerService.incrementDailyAdCount(AdType.optional);
    _trackerService.incrementLifetimeAdCount(AdType.optional);
    _checkBadges();
  }

  /// Check and award badges after ad activity.
  void _checkBadges() {
    final newBadges = _badgeService.checkAndAwardBadges(
      dailyAdCount: _trackerService.dailyAdsWatched,
      dailyForcedAdCount: _trackerService.trackingData.dailyForcedAds,
    );
    if (newBadges.isNotEmpty) {
      _newlyEarnedBadges = newBadges;
      notifyListeners();
    }
  }

  /// Show a forced ad for the given placement.
  /// Returns the reward amount earned, or null if the ad failed.
  Future<int?> showForcedAd(
    AdPlacement placement, {
    required void Function(int amount) onReward,
    VoidCallback? onAdDismissed,
    void Function(String error)? onAdFailed,
  }) async {
    if (!_trackerService.canShowForcedAd()) {
      onAdFailed?.call('Daily forced ad limit reached');
      return null;
    }

    _isShowingAd = true;
    _adLoadStatuses[placement] = AdLoadStatus.loading;
    notifyListeners();

    final ad = await _getOrLoadAd(placement);
    if (ad == null) {
      _adLoadStatuses[placement] = AdLoadStatus.failed;
      _isShowingAd = false;
      notifyListeners();
      onAdFailed?.call('Failed to load ad');
      return null;
    }

    _adLoadStatuses[placement] = AdLoadStatus.loaded;
    notifyListeners();

    final completer = Completer<int?>();

    await _adService.showRewardedAd(
      ad,
      placement: placement,
      onReward: (amount) async {
        _trackerService.incrementDailyAdCount(AdType.forced);
        _trackerService.incrementLifetimeAdCount(AdType.forced);
        _trackerService.incrementPlacementCount(placement);
        _checkBadges();
        onReward(amount);
        completer.complete(amount);
      },
      onAdDismissed: () {
        _isShowingAd = false;
        notifyListeners();
        onAdDismissed?.call();
      },
      onAdFailedToShow: (error) async {
        _isShowingAd = false;
        _adLoadStatuses[placement] = AdLoadStatus.failed;
        notifyListeners();
        onAdFailed?.call(error.message);
        completer.complete(null);
      },
    );

    _adLoadStatuses[placement] = AdLoadStatus.displayed;
    notifyListeners();
    return completer.future;
  }

  /// Show an optional ad for the given placement.
  /// Returns the reward amount earned, or null if the ad failed.
  Future<int?> showOptionalAd(
    AdPlacement placement, {
    required Future<void> Function(int amount) onReward,
    VoidCallback? onAdDismissed,
    Future<void> Function(String error)? onAdFailed,
  }) async {
    if (!_trackerService.canShowOptionalAd()) {
      await onAdFailed?.call('Daily optional ad limit reached');
      return null;
    }

    _isShowingAd = true;
    _adLoadStatuses[placement] = AdLoadStatus.loading;
    notifyListeners();

    final ad = await _getOrLoadAd(placement);
    if (ad == null) {
      _adLoadStatuses[placement] = AdLoadStatus.failed;
      _isShowingAd = false;
      notifyListeners();
      await onAdFailed?.call('Failed to load ad');
      return null;
    }

    _adLoadStatuses[placement] = AdLoadStatus.loaded;
    notifyListeners();

    final completer = Completer<int?>();

    await _adService.showRewardedAd(
      ad,
      placement: placement,
      onReward: (amount) async {
        _trackerService.incrementDailyAdCount(AdType.optional);
        _trackerService.incrementLifetimeAdCount(AdType.optional);
        _trackerService.incrementPlacementCount(placement);
        _checkBadges();
        await onReward(amount);
        completer.complete(amount);
      },
      onAdDismissed: () {
        _isShowingAd = false;
        notifyListeners();
        onAdDismissed?.call();
      },
      onAdFailedToShow: (error) async {
        _isShowingAd = false;
        _adLoadStatuses[placement] = AdLoadStatus.failed;
        notifyListeners();
        await onAdFailed?.call(error.message);
        completer.complete(null);
      },
    );

    _adLoadStatuses[placement] = AdLoadStatus.displayed;
    notifyListeners();
    return completer.future;
  }

  /// Get a preloaded ad or load a new one.
  Future<RewardedAd?> _getOrLoadAd(AdPlacement placement) async {
    if (_preloadedAds.containsKey(placement) &&
        _preloadedAds[placement] != null) {
      final ad = _preloadedAds[placement]!;
      _preloadedAds.remove(placement);
      _adService.preloadForPlacement(placement);
      return ad;
    }

    final ad = await _adService.loadRewardedAd(placement);
    _adService.preloadForPlacement(placement);
    return ad;
  }

  /// Preload ads for a list of placements.
  Future<void> preloadForPlacements(List<AdPlacement> placements) async {
    for (final placement in placements) {
      if (_preloadedAds[placement] == null) {
        final ad = await _adService.loadRewardedAd(placement);
        if (ad != null) {
          _preloadedAds[placement] = ad;
          _adLoadStatuses[placement] = AdLoadStatus.loaded;
        }
      }
    }
    notifyListeners();
  }

  /// Show an interstitial ad after a user claim/action.
  /// No reward is given — this is pure monetization.
  /// Silently skips if no ad is preloaded or on web.
  Future<void> showInterstitialAfterClaim(AdPlacement placement) async {
    _isShowingAd = true;
    notifyListeners();
    await _adService.showInterstitial(placement, onAdDismissed: () {
      _isShowingAd = false;
      notifyListeners();
    });
  }

  /// Preload interstitial for a specific placement.
  Future<void> preloadInterstitial(AdPlacement placement) async {
    await _adService.preloadInterstitial(placement);
  }

  /// Show a rewarded interstitial ad (for two-tier "Quick Claim" option).
  /// Returns true if user watched and earned reward, false otherwise.
  Future<bool> showRewardedInterstitial(
    AdPlacement placement, {
    required Future<void> Function(int amount) onReward,
    VoidCallback? onAdDismissed,
    Future<void> Function(String error)? onAdFailed,
  }) async {
    _isShowingAd = true;
    notifyListeners();

    final success = await _adService.showRewardedInterstitial(
      placement,
      onReward: (amount) async {
        _trackerService.incrementDailyAdCount(AdType.optional);
        _trackerService.incrementLifetimeAdCount(AdType.optional);
        _trackerService.incrementPlacementCount(placement);
        _checkBadges();
        await onReward(amount);
      },
      onAdDismissed: () {
        _isShowingAd = false;
        notifyListeners();
        onAdDismissed?.call();
      },
      onAdFailed: (error) async {
        _isShowingAd = false;
        notifyListeners();
        await onAdFailed?.call(error);
      },
    );

    return success;
  }

  @override
  void dispose() {
    _adService.dispose();
    super.dispose();
  }
}
