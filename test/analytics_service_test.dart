import 'package:flutter_test/flutter_test.dart';
import 'package:rbx_rewards_app/services/analytics_service.dart';

void main() {
  group('AnalyticsService', () {
    late AnalyticsService analytics;

    setUp(() {
      analytics = AnalyticsService();
      analytics.resetMetrics();
    });

    test('logAdImpression increments per placement', () {
      analytics.logAdImpression('daily_reward');
      analytics.logAdImpression('daily_reward');
      analytics.logAdImpression('chest_open');
      expect(analytics.impressionsFor('daily_reward'), 2);
      expect(analytics.impressionsFor('chest_open'), 1);
      expect(analytics.impressionsFor('spin'), 0);
    });

    test('logAdLoadSuccess records load time', () {
      analytics.logAdLoadSuccess('daily_reward', 1200);
      analytics.logAdLoadSuccess('daily_reward', 800);
      expect(analytics.avgLoadTimeMsFor('daily_reward'), 1000.0);
    });

    test('fill rate calculation', () {
      analytics.logAdLoadSuccess('daily_reward', 1000);
      analytics.logAdLoadSuccess('daily_reward', 1200);
      analytics.logAdFailure('daily_reward', 'network_error');
      expect(analytics.fillRateFor('daily_reward'), closeTo(0.67, 0.01));
    });

    test('drop-off rate calculation', () {
      analytics.logAdStarted('daily_reward');
      analytics.logAdStarted('daily_reward');
      analytics.logAdStarted('daily_reward');
      analytics.logAdCompletion('daily_reward');
      expect(analytics.dropOffRateFor('daily_reward'), closeTo(0.67, 0.01));
    });

    test('revenue aggregation', () {
      analytics.logAdRevenue('daily_reward', 0.05);
      analytics.logAdRevenue('daily_reward', 0.03);
      expect(analytics.revenueFor('daily_reward'), closeTo(0.08, 0.001));
    });

    test('resetMetrics clears all data', () {
      analytics.logAdImpression('daily_reward');
      analytics.logAdLoadSuccess('daily_reward', 1000);
      analytics.logAdFailure('daily_reward', 'error');
      analytics.logAdStarted('daily_reward');
      analytics.logAdCompletion('daily_reward');
      analytics.logAdRevenue('daily_reward', 0.05);
      analytics.resetMetrics();
      expect(analytics.impressionsFor('daily_reward'), 0);
      expect(analytics.fillRateFor('daily_reward'), 0.0);
      expect(analytics.dropOffRateFor('daily_reward'), 0.0);
      expect(analytics.revenueFor('daily_reward'), 0.0);
      expect(analytics.avgLoadTimeMsFor('daily_reward'), 0.0);
    });

    test('zero values when no data', () {
      expect(analytics.fillRateFor('spin'), 0.0);
      expect(analytics.avgLoadTimeMsFor('spin'), 0.0);
      expect(analytics.dropOffRateFor('spin'), 0.0);
      expect(analytics.revenueFor('spin'), 0.0);
      expect(analytics.impressionsFor('spin'), 0);
    });

    test('logFrequencyCapping does not throw', () {
      expect(() => analytics.logFrequencyCapping('creative_1', 3), returnsNormally);
    });
  });
}
