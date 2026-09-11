import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rbx_rewards/business/ad_tracker_service.dart';
import 'package:rbx_rewards/models/ad_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('AdTrackerService 20-Max Daily Limit Tests', () {
    late AdTrackerService service;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      service = AdTrackerService();
      await service.load();
      await service.resetDailyCounters();
    });

    test('Default limits are configured to 20 max', () {
      expect(AdTrackerService.maxDailyTotalAds, 20);
      expect(AdTrackerService.maxDailyOptionalAds, 20);
      expect(AdTrackerService.maxDailyForcedAds, 10);
    });

    test('Allows optional ads until daily 20 limit is reached', () async {
      for (int i = 0; i < 19; i++) {
        expect(service.canShowOptionalAd(), isTrue);
        await service.incrementDailyAdCount(AdType.optional);
      }

      // 19th ad watched, 1 remaining
      expect(service.dailyAdsWatched, 19);
      expect(service.getRemainingOptionalAds(), 1);
      expect(service.canShowOptionalAd(), isTrue);

      // 20th ad watched
      await service.incrementDailyAdCount(AdType.optional);
      expect(service.dailyAdsWatched, 20);
      expect(service.canShowOptionalAd(), isFalse);
      expect(service.canShowForcedAd(), isFalse);
      expect(service.getRemainingOptionalAds(), 0);
      expect(service.getRemainingForcedAds(), 0);
    });

    test('Total cap of 20 stops optional ads if forced ads also contributed', () async {
      // 5 forced ads
      for (int i = 0; i < 5; i++) {
        await service.incrementDailyAdCount(AdType.forced);
      }
      expect(service.dailyAdsWatched, 5);

      // 15 optional ads
      for (int i = 0; i < 15; i++) {
        await service.incrementDailyAdCount(AdType.optional);
      }
      expect(service.dailyAdsWatched, 20);

      // Both should be capped at 20 total
      expect(service.canShowOptionalAd(), isFalse);
      expect(service.canShowForcedAd(), isFalse);
      expect(service.getRemainingOptionalAds(), 0);
    });
  });
}
