import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../models/ad_models.dart';
import '../../models/badge_model.dart';
import 'providers.dart';

class AdStateModel {
  final Map<AdPlacement, AdLoadStatus> adLoadStatuses;
  final bool isInitialized;
  final bool isShowingAd;
  final List<Badge> newlyEarnedBadges;

  AdStateModel({
    required this.adLoadStatuses,
    required this.isInitialized,
    required this.isShowingAd,
    required this.newlyEarnedBadges,
  });

  AdStateModel copyWith({
    Map<AdPlacement, AdLoadStatus>? adLoadStatuses,
    bool? isInitialized,
    bool? isShowingAd,
    List<Badge>? newlyEarnedBadges,
  }) {
    return AdStateModel(
      adLoadStatuses: adLoadStatuses ?? this.adLoadStatuses,
      isInitialized: isInitialized ?? this.isInitialized,
      isShowingAd: isShowingAd ?? this.isShowingAd,
      newlyEarnedBadges: newlyEarnedBadges ?? this.newlyEarnedBadges,
    );
  }
}

final adProvider = NotifierProvider<AdNotifier, AdStateModel>(() => AdNotifier());

class AdNotifier extends Notifier<AdStateModel> {
  final Map<AdPlacement, RewardedAd?> _preloadedAds = {};

  @override
  AdStateModel build() {
    return AdStateModel(
      adLoadStatuses: {},
      isInitialized: false,
      isShowingAd: false,
      newlyEarnedBadges: [],
    );
  }

  int get dailyAdsWatched => ref.read(adTrackerServiceProvider).dailyAdsWatched;
  int get remainingForcedAds => ref.read(adTrackerServiceProvider).getRemainingForcedAds();
  int get remainingOptionalAds => ref.read(adTrackerServiceProvider).getRemainingOptionalAds();
  bool get canShowForcedAd => ref.read(adTrackerServiceProvider).canShowForcedAd();
  bool get canShowOptionalAd => ref.read(adTrackerServiceProvider).canShowOptionalAd();
  int get dailyEarningsRemaining => ref.read(dailyCapServiceProvider).remainingToday;
  bool get isDailyCapReached => ref.read(dailyCapServiceProvider).isCapReached;

  AdLoadStatus statusFor(AdPlacement placement) {
    return state.adLoadStatuses[placement] ?? AdLoadStatus.notLoaded;
  }

  Future<void> initialize() async {
    final adService = ref.read(adServiceProvider);
    final trackerService = ref.read(adTrackerServiceProvider);
    final badgeService = ref.read(badgeServiceProvider);
    final dailyCapService = ref.read(dailyCapServiceProvider);

    await adService.initialize();
    await trackerService.load();
    await badgeService.load();
    await dailyCapService.load();
    await adService.preloadAds(2);

    // Preload interstitials
    await adService.preloadInterstitial(AdPlacement.dailyReward);
    await adService.preloadInterstitial(AdPlacement.chestOpen);
    await adService.preloadInterstitial(AdPlacement.chestInstantUnlock);
    await adService.preloadInterstitial(AdPlacement.spinForced);
    await adService.preloadInterstitial(AdPlacement.spinExtra);
    await adService.preloadInterstitial(AdPlacement.scratchCard);

    // Preload rewarded interstitials
    await adService.preloadRewardedInterstitial(AdPlacement.dailyReward);
    await adService.preloadRewardedInterstitial(AdPlacement.chestOpen);
    await adService.preloadRewardedInterstitial(AdPlacement.miniGameCompletion);
    await adService.preloadRewardedInterstitial(AdPlacement.scratchCard);
    await adService.preloadRewardedInterstitial(AdPlacement.doubleReward);

    state = state.copyWith(isInitialized: true);
  }

  void clearNewBadges() {
    state = state.copyWith(newlyEarnedBadges: []);
  }

  void recordOptionalAdWatched() {
    final tracker = ref.read(adTrackerServiceProvider);
    tracker.incrementDailyAdCount(AdType.optional);
    tracker.incrementLifetimeAdCount(AdType.optional);
    _checkBadges();
  }

  void _checkBadges() {
    final tracker = ref.read(adTrackerServiceProvider);
    final badgeService = ref.read(badgeServiceProvider);
    final newBadges = badgeService.checkAndAwardBadges(
      dailyAdCount: tracker.dailyAdsWatched,
      dailyForcedAdCount: tracker.trackingData.dailyForcedAds,
    );
    if (newBadges.isNotEmpty) {
      state = state.copyWith(newlyEarnedBadges: newBadges);
    }
  }

  Future<RewardedAd?> _getOrLoadAd(AdPlacement placement) async {
    final adService = ref.read(adServiceProvider);
    if (_preloadedAds.containsKey(placement) && _preloadedAds[placement] != null) {
      final ad = _preloadedAds[placement]!;
      _preloadedAds.remove(placement);
      adService.preloadForPlacement(placement);
      return ad;
    }

    final ad = await adService.loadRewardedAd(placement);
    adService.preloadForPlacement(placement);
    return ad;
  }

  Future<int?> showForcedAd(
    AdPlacement placement, {
    required void Function(int amount) onReward,
    VoidCallback? onAdDismissed,
    void Function(String error)? onAdFailed,
  }) async {
    final tracker = ref.read(adTrackerServiceProvider);
    if (!tracker.canShowForcedAd()) {
      onAdFailed?.call('Daily forced ad limit reached');
      return null;
    }

    _updatePlacementStatus(placement, AdLoadStatus.loading, isShowing: true);

    final ad = await _getOrLoadAd(placement);
    if (ad == null) {
      _updatePlacementStatus(placement, AdLoadStatus.failed, isShowing: false);
      onAdFailed?.call('Failed to load ad');
      return null;
    }

    _updatePlacementStatus(placement, AdLoadStatus.loaded);

    final completer = Completer<int?>();

    await ref.read(adServiceProvider).showRewardedAd(
      ad,
      placement: placement,
      onReward: (amount) async {
        tracker.incrementDailyAdCount(AdType.forced);
        tracker.incrementLifetimeAdCount(AdType.forced);
        tracker.incrementPlacementCount(placement);
        _checkBadges();
        onReward(amount);
        completer.complete(amount);
      },
      onAdDismissed: () {
        state = state.copyWith(isShowingAd: false);
        onAdDismissed?.call();
      },
      onAdFailedToShow: (error) async {
        _updatePlacementStatus(placement, AdLoadStatus.failed, isShowing: false);
        onAdFailed?.call(error.message);
        completer.complete(null);
      },
    );

    _updatePlacementStatus(placement, AdLoadStatus.displayed);
    return completer.future;
  }

  Future<int?> showOptionalAd(
    AdPlacement placement, {
    required Future<void> Function(int amount) onReward,
    VoidCallback? onAdDismissed,
    Future<void> Function(String error)? onAdFailed,
  }) async {
    final tracker = ref.read(adTrackerServiceProvider);
    if (!tracker.canShowOptionalAd()) {
      await onAdFailed?.call('Daily optional ad limit reached');
      return null;
    }

    _updatePlacementStatus(placement, AdLoadStatus.loading, isShowing: true);

    final ad = await _getOrLoadAd(placement);
    if (ad == null) {
      _updatePlacementStatus(placement, AdLoadStatus.failed, isShowing: false);
      await onAdFailed?.call('Failed to load ad');
      return null;
    }

    _updatePlacementStatus(placement, AdLoadStatus.loaded);

    final completer = Completer<int?>();

    await ref.read(adServiceProvider).showRewardedAd(
      ad,
      placement: placement,
      onReward: (amount) async {
        tracker.incrementDailyAdCount(AdType.optional);
        tracker.incrementLifetimeAdCount(AdType.optional);
        tracker.incrementPlacementCount(placement);
        _checkBadges();
        await onReward(amount);
        completer.complete(amount);
      },
      onAdDismissed: () {
        state = state.copyWith(isShowingAd: false);
        onAdDismissed?.call();
      },
      onAdFailedToShow: (error) async {
        _updatePlacementStatus(placement, AdLoadStatus.failed, isShowing: false);
        await onAdFailed?.call(error.message);
        completer.complete(null);
      },
    );

    _updatePlacementStatus(placement, AdLoadStatus.displayed);
    return completer.future;
  }

  Future<void> showInterstitialAfterClaim(AdPlacement placement) async {
    state = state.copyWith(isShowingAd: true);
    await ref.read(adServiceProvider).showInterstitial(placement, onAdDismissed: () {
      state = state.copyWith(isShowingAd: false);
    });
  }

  Future<bool> showRewardedInterstitial(
    AdPlacement placement, {
    required Future<void> Function(int amount) onReward,
    VoidCallback? onAdDismissed,
    Future<void> Function(String error)? onAdFailed,
  }) async {
    state = state.copyWith(isShowingAd: true);
    final tracker = ref.read(adTrackerServiceProvider);

    final success = await ref.read(adServiceProvider).showRewardedInterstitial(
      placement,
      onReward: (amount) async {
        tracker.incrementDailyAdCount(AdType.optional);
        tracker.incrementLifetimeAdCount(AdType.optional);
        tracker.incrementPlacementCount(placement);
        _checkBadges();
        await onReward(amount);
      },
      onAdDismissed: () {
        state = state.copyWith(isShowingAd: false);
        onAdDismissed?.call();
      },
      onAdFailed: (error) async {
        state = state.copyWith(isShowingAd: false);
        await onAdFailed?.call(error);
      },
    );

    return success;
  }

  void _updatePlacementStatus(AdPlacement placement, AdLoadStatus status, {bool? isShowing}) {
    final updatedStatuses = Map<AdPlacement, AdLoadStatus>.from(state.adLoadStatuses);
    updatedStatuses[placement] = status;
    state = state.copyWith(
      adLoadStatuses: updatedStatuses,
      isShowingAd: isShowing ?? state.isShowingAd,
    );
  }
}
