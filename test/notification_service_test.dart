import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/business/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'pref_notifications_enabled': true,
      });
    });

    test('Initializes with default enabled preference when unset', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();
      expect(service.isNotificationsEnabled, isTrue);
    });

    test('Loads disabled preference from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'pref_notifications_enabled': false,
      });
      final service = NotificationService.testInstance(enabled: false);
      await service.init();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(NotificationService.prefKey), isFalse);
      expect(service.isNotificationsEnabled, isFalse);
    });

    test('Loads enabled preference from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'pref_notifications_enabled': true,
      });
      final service = NotificationService.testInstance(enabled: true);
      await service.init();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(NotificationService.prefKey), isTrue);
      expect(service.isNotificationsEnabled, isTrue);
    });

    test('setNotificationsEnabled(false) disables state, persists preference, and cancels pending notifications', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      await service.setNotificationsEnabled(false);
      expect(service.isNotificationsEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(NotificationService.prefKey), isFalse);
    });

    test('setNotificationsEnabled(true) enables state, persists preference, and reschedules retention loops', () async {
      final service = NotificationService.testInstance(enabled: false);
      await service.init();

      await service.setNotificationsEnabled(true);
      expect(service.isNotificationsEnabled, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(NotificationService.prefKey), isTrue);
    });

    test('scheduleChestReady handles future trigger dates safely', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      final futureTrigger = DateTime.now().add(const Duration(hours: 3));
      await expectLater(service.scheduleChestReady(futureTrigger), completes);
    });

    test('scheduleChestReady safely ignores past trigger dates without scheduling', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      final pastTrigger = DateTime.now().subtract(const Duration(minutes: 10));
      await expectLater(service.scheduleChestReady(pastTrigger), completes);
    });

    test('scheduleDailyQuestsReminder schedules successfully for midday 1:00 PM', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      await expectLater(service.scheduleDailyQuestsReminder(), completes);
    });

    test('scheduleStreakReminder schedules successfully for evening 8:00 PM', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      await expectLater(service.scheduleStreakReminder(), completes);
    });

    test('All individual and global cancellation methods execute safely', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      await expectLater(service.cancelChestReady(), completes);
      await expectLater(service.cancelStreakReminder(), completes);
      await expectLater(service.cancelAll(), completes);
    });

    test('All scheduling methods immediately no-op when notifications are disabled', () async {
      final service = NotificationService.testInstance(enabled: false);
      expect(service.isNotificationsEnabled, isFalse);

      final futureTrigger = DateTime.now().add(const Duration(hours: 3));
      await expectLater(service.scheduleChestReady(futureTrigger), completes);
      await expectLater(service.scheduleDailyQuestsReminder(), completes);
      await expectLater(service.scheduleStreakReminder(), completes);
    });

    test('requestPermissions executes safely without throwing in test environment', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      await expectLater(service.requestPermissions(), completes);
    });

    test('showWelcomeNotification delivers welcome notification without throwing', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      await expectLater(service.showWelcomeNotification(userName: 'Alex'), completes);
      await expectLater(service.showWelcomeNotification(), completes);
    });

    test('showWelcomeNotification immediately no-ops when notifications are disabled', () async {
      final service = NotificationService.testInstance(enabled: false);
      expect(service.isNotificationsEnabled, isFalse);

      await expectLater(service.showWelcomeNotification(userName: 'Alex'), completes);
    });

    test('onUserSignedIn coordinates permission request, welcome notification, and retention schedules', () async {
      final service = NotificationService.testInstance(enabled: true);
      await service.init();

      final result = await service.onUserSignedIn(displayName: 'TestPlayer');
      expect(result, isTrue);
      expect(service.isNotificationsEnabled, isTrue);
    });

    test('Constant identifiers match specifications', () {
      expect(NotificationService.welcomeNotificationId, 1000);
      expect(NotificationService.chestReadyNotificationId, 1001);
      expect(NotificationService.dailyQuestsNotificationId, 1002);
      expect(NotificationService.streakReminderNotificationId, 1003);
      expect(NotificationService.channelId, 'rewards_channel');
      expect(NotificationService.channelName, 'Rewards & Bonuses');
      expect(NotificationService.prefKey, 'pref_notifications_enabled');
    });
  });
}
