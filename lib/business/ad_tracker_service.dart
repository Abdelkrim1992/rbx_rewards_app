import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ad_models.dart';

/// Tracks daily/lifetime ad counts, enforces limits, and syncs to backend.
class AdTrackerService {
  static const int maxDailyTotalAds = 20;
  static const int maxDailyOptionalAds = 20;
  static const int maxDailyForcedAds = 10;
  static const int _syncThreshold = 10;

  static const _secureStorage = FlutterSecureStorage();
  final SupabaseClient? _supabase;
  AdTrackingData _trackingData = AdTrackingData(
    lastResetDate: DateTime.now(),
  );
  int _adsSinceLastSync = 0;
  bool _limitFlagOverride = false;

  AdTrackerService({SupabaseClient? supabase}) : _supabase = supabase;

  AdTrackingData get trackingData => _trackingData;

  /// Load persisted tracking data.
  Future<void> load() async {
    final jsonStr = await _secureStorage.read(key: 'ad_tracking_data');
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _trackingData = AdTrackingData.fromJson(map);
      } catch (e) {
        debugPrint('AdTrackerService: failed to parse tracking data');
      }
    }
    _checkMidnightReset();
  }

  void _checkMidnightReset() {
    final now = DateTime.now();
    final last = _trackingData.lastResetDate;
    if (now.year != last.year ||
        now.month != last.month ||
        now.day != last.day) {
      resetDailyCounters();
    }
  }

  /// Increment daily ad count by type.
  Future<void> incrementDailyAdCount(AdType type) async {
    _checkMidnightReset();
    if (type == AdType.forced) {
      _trackingData.dailyForcedAds++;
    } else {
      _trackingData.dailyOptionalAds++;
    }
    await _persistCounters();
  }

  /// Increment lifetime ad count by type (only on completion).
  Future<void> incrementLifetimeAdCount(AdType type) async {
    if (type == AdType.forced) {
      _trackingData.lifetimeForcedAds++;
    } else {
      _trackingData.lifetimeOptionalAds++;
    }
    _adsSinceLastSync++;
    if (_adsSinceLastSync >= _syncThreshold) {
      await _syncToBackend();
    }
    await _persistCounters();
  }

  /// Increment per-placement count.
  Future<void> incrementPlacementCount(AdPlacement placement) async {
    final key = placement.name;
    _trackingData.placementCounts[key] =
        (_trackingData.placementCounts[key] ?? 0) + 1;
    await _persistCounters();
  }

  Future<void> _persistCounters() async {
    await _secureStorage.write(
      key: 'ad_tracking_data',
      value: jsonEncode(_trackingData.toJson()),
    );
  }

  /// Whether a forced ad can be shown today.
  bool canShowForcedAd() {
    _checkMidnightReset();
    if (_limitFlagOverride) return true;
    if (dailyAdsWatched >= maxDailyTotalAds) return false;
    return _trackingData.dailyForcedAds < maxDailyForcedAds;
  }

  /// Whether an optional ad can be shown today.
  bool canShowOptionalAd() {
    _checkMidnightReset();
    if (_limitFlagOverride) return true;
    if (dailyAdsWatched >= maxDailyTotalAds) return false;
    return _trackingData.dailyOptionalAds < maxDailyOptionalAds;
  }

  int getRemainingForcedAds() {
    _checkMidnightReset();
    final remainingTotal = (maxDailyTotalAds - dailyAdsWatched).clamp(0, maxDailyTotalAds);
    final remainingForced = (maxDailyForcedAds - _trackingData.dailyForcedAds).clamp(0, maxDailyForcedAds);
    return remainingTotal < remainingForced ? remainingTotal : remainingForced;
  }

  int getRemainingOptionalAds() {
    _checkMidnightReset();
    final remainingTotal = (maxDailyTotalAds - dailyAdsWatched).clamp(0, maxDailyTotalAds);
    final remainingOptional = (maxDailyOptionalAds - _trackingData.dailyOptionalAds).clamp(0, maxDailyOptionalAds);
    return remainingTotal < remainingOptional ? remainingTotal : remainingOptional;
  }

  int get dailyAdsWatched =>
      _trackingData.dailyForcedAds + _trackingData.dailyOptionalAds;

  /// Reset daily counters (typically at midnight).
  Future<void> resetDailyCounters() async {
    _trackingData = _trackingData.copyWith(
      dailyForcedAds: 0,
      dailyOptionalAds: 0,
      lastResetDate: DateTime.now(),
    );
    await _persistCounters();
  }

  /// Override limits for testing.
  void setLimitFlagOverride(bool enabled) {
    _limitFlagOverride = enabled;
  }

  /// Sync lifetime counters to Supabase.
  Future<void> _syncToBackend() async {
    final client = _supabase ?? Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await client.from('user_ad_stats').upsert({
        'user_id': uid,
        'lifetime_forced_ads': _trackingData.lifetimeForcedAds,
        'lifetime_optional_ads': _trackingData.lifetimeOptionalAds,
        'placement_counts': _trackingData.placementCounts,
        'updated_at': DateTime.now().toIso8601String(),
      });
      _adsSinceLastSync = 0;
    } catch (e) {
      debugPrint('AdTrackerService: sync failed: $e');
    }
  }

  /// Force a backend sync.
  Future<void> forceSync() async {
    await _syncToBackend();
  }
}
