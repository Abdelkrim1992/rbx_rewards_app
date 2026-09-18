import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rbx_rewards/business/ad_tracker_service.dart';
import 'package:rbx_rewards/models/ad_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('AdTrackerService 60-Max Daily Limit Tests', () {
    late AdTrackerService service;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      service = AdTrackerService();
      await service.load();
      await service.resetDailyCounters();
    });

    test('Default limits are configured to 60 total and 55 optional max', () {
      expect(AdTrackerService.maxDailyTotalAds, 60);
      expect(AdTrackerService.maxDailyOptionalAds, 55);
      expect(AdTrackerService.maxDailyForcedAds, 10);
    });

    test('Allows optional ads until daily 55 optional limit is reached', () async {
      for (int i = 0; i < 54; i++) {
        expect(service.canShowOptionalAd(), isTrue);
        await service.incrementDailyAdCount(AdType.optional);
      }

      // 54th ad watched, 1 remaining optional
      expect(service.dailyAdsWatched, 54);
      expect(service.getRemainingOptionalAds(), 1);
      expect(service.canShowOptionalAd(), isTrue);

      // 55th ad watched
      await service.incrementDailyAdCount(AdType.optional);
      expect(service.dailyAdsWatched, 55);
      expect(service.canShowOptionalAd(), isFalse);
      expect(service.getRemainingOptionalAds(), 0);
      // Forced ads still has remaining slots up to 60 total
      expect(service.canShowForcedAd(), isTrue);
      expect(service.getRemainingForcedAds(), 5);
    });

    test('Total cap of 60 stops optional ads if forced ads also contributed', () async {
      // 10 forced ads
      for (int i = 0; i < 10; i++) {
        await service.incrementDailyAdCount(AdType.forced);
      }
      expect(service.dailyAdsWatched, 10);

      // 50 optional ads (total = 60)
      for (int i = 0; i < 50; i++) {
        await service.incrementDailyAdCount(AdType.optional);
      }
      expect(service.dailyAdsWatched, 60);

      // Both should be capped at 60 total
      expect(service.canShowOptionalAd(), isFalse);
      expect(service.canShowForcedAd(), isFalse);
      expect(service.getRemainingOptionalAds(), 0);
    });

    test('Tracking data properly counts daily forced and optional ads', () async {
      await service.incrementDailyAdCount(AdType.forced);
      await service.incrementDailyAdCount(AdType.optional);
      await service.incrementDailyAdCount(AdType.optional);

      expect(service.trackingData.dailyForcedAds, 1);
      expect(service.trackingData.dailyOptionalAds, 2);
      expect(service.dailyAdsWatched, 3);

      await service.resetDailyCounters();
      expect(service.trackingData.dailyForcedAds, 0);
      expect(service.trackingData.dailyOptionalAds, 0);
      expect(service.dailyAdsWatched, 0);
    });
  });
}
