import 'package:flutter/foundation.dart';

/// Placement types for ads across the app.
enum AdPlacement {
  dailyReward,
  chestOpen,
  chestInstantUnlock,
  spinForced,
  spinExtra,
  miniGameCompletion,
  scratchCard,
  doubleReward,
  luckyBonus,
}

/// Whether the ad is forced (required to proceed) or optional.
enum AdType { forced, optional }

/// Current load state of an ad.
enum AdLoadStatus { notLoaded, loading, loaded, failed, displayed }

/// Configuration for a specific ad placement.
class AdConfig {
  final String adUnitId;
  final AdPlacement placement;
  final AdType type;
  final int maxDailyCount;
  final int rewardAmount;
  final String displayMessage;

  const AdConfig({
    required this.adUnitId,
    required this.placement,
    required this.type,
    required this.maxDailyCount,
    required this.rewardAmount,
    required this.displayMessage,
  });
}

/// Serializable tracking data for ad counters.
class AdTrackingData {
  int dailyForcedAds;
  int dailyOptionalAds;
  int lifetimeForcedAds;
  int lifetimeOptionalAds;
  DateTime lastResetDate;
  Map<String, int> placementCounts;

  AdTrackingData({
    this.dailyForcedAds = 0,
    this.dailyOptionalAds = 0,
    this.lifetimeForcedAds = 0,
    this.lifetimeOptionalAds = 0,
    required this.lastResetDate,
    Map<String, int>? placementCounts,
  }) : placementCounts = placementCounts ?? {};

  factory AdTrackingData.fromJson(Map<String, dynamic> json) {
    return AdTrackingData(
      dailyForcedAds: json['dailyForcedAds'] as int? ?? 0,
      dailyOptionalAds: json['dailyOptionalAds'] as int? ?? 0,
      lifetimeForcedAds: json['lifetimeForcedAds'] as int? ?? 0,
      lifetimeOptionalAds: json['lifetimeOptionalAds'] as int? ?? 0,
      lastResetDate: json['lastResetDate'] != null
          ? DateTime.parse(json['lastResetDate'] as String)
          : DateTime.now(),
      placementCounts: (json['placementCounts'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
    );
  }

  Map<String, dynamic> toJson() => {
    'dailyForcedAds': dailyForcedAds,
    'dailyOptionalAds': dailyOptionalAds,
    'lifetimeForcedAds': lifetimeForcedAds,
    'lifetimeOptionalAds': lifetimeOptionalAds,
    'lastResetDate': lastResetDate.toIso8601String(),
    'placementCounts': placementCounts,
  };

  AdTrackingData copyWith({
    int? dailyForcedAds,
    int? dailyOptionalAds,
    int? lifetimeForcedAds,
    int? lifetimeOptionalAds,
    DateTime? lastResetDate,
    Map<String, int>? placementCounts,
  }) {
    return AdTrackingData(
      dailyForcedAds: dailyForcedAds ?? this.dailyForcedAds,
      dailyOptionalAds: dailyOptionalAds ?? this.dailyOptionalAds,
      lifetimeForcedAds: lifetimeForcedAds ?? this.lifetimeForcedAds,
      lifetimeOptionalAds: lifetimeOptionalAds ?? this.lifetimeOptionalAds,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      placementCounts: placementCounts ?? Map.from(this.placementCounts),
    );
  }
}

extension AdPlacementName on AdPlacement {
  String get name {
    switch (this) {
      case AdPlacement.dailyReward:
        return 'dailyReward';
      case AdPlacement.chestOpen:
        return 'chestOpen';
      case AdPlacement.chestInstantUnlock:
        return 'chestInstantUnlock';
      case AdPlacement.spinForced:
        return 'spinForced';
      case AdPlacement.spinExtra:
        return 'spinExtra';
      case AdPlacement.miniGameCompletion:
        return 'miniGameCompletion';
      case AdPlacement.scratchCard:
        return 'scratchCard';
      case AdPlacement.doubleReward:
        return 'doubleReward';
      case AdPlacement.luckyBonus:
        return 'luckyBonus';
    }
  }
}
