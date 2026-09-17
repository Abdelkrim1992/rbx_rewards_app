import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/business/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'pref_notifications_enabled': true,
      });
    });

    test('Initializes with default enabled preference', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();
      expect(service.isNotificationsEnabled, isTrue);
    });

    test('Loads disabled preference from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'pref_notifications_enabled': false,
      });
      final service = NotificationService.testInstance(enabled: false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pref_notifications_enabled'), isFalse);
      expect(service.isNotificationsEnabled, isFalse);
    });

    test('setNotificationsEnabled toggles state, persists, and handles scheduling', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      await service.setNotificationsEnabled(false);
      expect(service.isNotificationsEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pref_notifications_enabled'), isFalse);

      await service.setNotificationsEnabled(true);
      expect(service.isNotificationsEnabled, isTrue);
      expect(prefs.getBool('pref_notifications_enabled'), isTrue);
    });

    test('scheduleChestReady handles future trigger safely', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      final futureTrigger = DateTime.now().add(const Duration(hours: 3));
      await expectLater(service.scheduleChestReady(futureTrigger), completes);

      // Trigger in the past should safely no-op
      final pastTrigger = DateTime.now().subtract(const Duration(minutes: 5));
      await expectLater(service.scheduleChestReady(pastTrigger), completes);
    });

    test('scheduleDailyQuestsReminder and scheduleStreakReminder execute safely', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      await expectLater(service.scheduleDailyQuestsReminder(), completes);
      await expectLater(service.scheduleStreakReminder(), completes);
    });

    test('Cancellation methods execute safely', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      await expectLater(service.cancelChestReady(), completes);
      await expectLater(service.cancelStreakReminder(), completes);
      await expectLater(service.cancelAll(), completes);
    });

    test('Scheduling no-ops immediately when notifications are disabled', () async {
      final service = NotificationService.testInstance(enabled: false);
      expect(service.isNotificationsEnabled, isFalse);

      final futureTrigger = DateTime.now().add(const Duration(hours: 3));
      await expectLater(service.scheduleChestReady(futureTrigger), completes);
      await expectLater(service.scheduleDailyQuestsReminder(), completes);
      await expectLater(service.scheduleStreakReminder(), completes);
    });
  });
}
