import 'package:flutter/foundation.dart';

/// Lightweight analytics service for ad-related events.
/// In production, wire this to Firebase Analytics or similar.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // Placement-level tracking
  final Map<String, int> _impressionsByPlacement = {};
  final Map<String, int> _loadsByPlacement = {};
  final Map<String, int> _loadFailuresByPlacement = {};
  final Map<String, List<int>> _loadTimesByPlacement = {};
  final Map<String, int> _startedByPlacement = {};
  final Map<String, int> _completedByPlacement = {};
  final Map<String, double> _revenueByPlacement = {};

  /// Log an ad impression event.
  void logAdImpression(String placement, {String? network}) {
    _impressionsByPlacement[placement] =
        (_impressionsByPlacement[placement] ?? 0) + 1;
    debugPrint(
        '[Analytics] ad_impression: placement=$placement network=$network');
  }

  /// Log an ad click event.
  void logAdClick(String placement) {
    debugPrint('[Analytics] ad_click: placement=$placement');
  }

  /// Log an ad completion (reward earned) event.
  void logAdCompletion(String placement) {
    _completedByPlacement[placement] =
        (_completedByPlacement[placement] ?? 0) + 1;
    debugPrint('[Analytics] ad_completion: placement=$placement');
  }

  /// Log that an ad started playing.
  void logAdStarted(String placement) {
    _startedByPlacement[placement] = (_startedByPlacement[placement] ?? 0) + 1;
    debugPrint('[Analytics] ad_started: placement=$placement');
  }

  /// Log an ad failure event.
  void logAdFailure(String placement, String error) {
    _loadFailuresByPlacement[placement] =
        (_loadFailuresByPlacement[placement] ?? 0) + 1;
    debugPrint('[Analytics] ad_failure: placement=$placement error=$error');
  }

  /// Log ad load success with duration.
  void logAdLoadSuccess(String placement, int loadTimeMs) {
    _loadsByPlacement[placement] = (_loadsByPlacement[placement] ?? 0) + 1;
    (_loadTimesByPlacement[placement] ??= []).add(loadTimeMs);
    debugPrint(
        '[Analytics] ad_load_success: placement=$placement timeMs=$loadTimeMs');
  }

  /// Log estimated ad revenue.
  void logAdRevenue(String placement, double revenue) {
    _revenueByPlacement[placement] =
        (_revenueByPlacement[placement] ?? 0.0) + revenue;
    debugPrint('[Analytics] ad_revenue: placement=$placement revenue=$revenue');
  }

  /// Log mediation network performance.
  void logMediationPerformance(String network, double fillRate, double eCPM) {
    debugPrint(
        '[Analytics] mediation_performance: network=$network fillRate=$fillRate eCPM=$eCPM');
  }

  /// Log ARPDAU metric.
  void logARPDAU(double value) {
    debugPrint('[Analytics] arpdau: value=$value');
  }

  /// Log frequency capping event.
  void logFrequencyCapping(String creativeId, int impressionCount) {
    debugPrint(
        '[Analytics] frequency_capping: creative=$creativeId count=$impressionCount');
  }

  /// Log a generic event.
  void logEvent(String name, Map<String, dynamic> parameters) {
    debugPrint('[Analytics] event=$name params=$parameters');
  }

  // --- Aggregated metrics ---

  /// Fill rate per placement (0.0 - 1.0)
  double fillRateFor(String placement) {
    final loads = _loadsByPlacement[placement] ?? 0;
    final fails = _loadFailuresByPlacement[placement] ?? 0;
    final total = loads + fails;
    return total == 0 ? 0.0 : loads / total;
  }

  /// Average load time in ms for a placement.
  double avgLoadTimeMsFor(String placement) {
    final times = _loadTimesByPlacement[placement];
    if (times == null || times.isEmpty) return 0.0;
    return times.reduce((a, b) => a + b) / times.length;
  }

  /// Drop-off rate for a placement (started but didn't complete).
  double dropOffRateFor(String placement) {
    final started = _startedByPlacement[placement] ?? 0;
    final completed = _completedByPlacement[placement] ?? 0;
    if (started == 0) return 0.0;
    return (started - completed) / started;
  }

  /// Total revenue per placement.
  double revenueFor(String placement) {
    return _revenueByPlacement[placement] ?? 0.0;
  }

  /// Total impressions per placement.
  int impressionsFor(String placement) {
    return _impressionsByPlacement[placement] ?? 0;
  }

  /// Reset all metrics (useful for daily reports).
  void resetMetrics() {
    _impressionsByPlacement.clear();
    _loadsByPlacement.clear();
    _loadFailuresByPlacement.clear();
    _loadTimesByPlacement.clear();
    _startedByPlacement.clear();
    _completedByPlacement.clear();
    _revenueByPlacement.clear();
  }
}
