import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Production-ready 100% on-device Smart Local Notification Engine.
/// Drives Day-1, Day-7, and Day-30 retention loops with zero server cost and full offline support.
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._internal();

  NotificationService._internal();

  @visibleForTesting
  factory NotificationService.testInstance({
    bool enabled = true,
    FlutterLocalNotificationsPlugin? plugin,
  }) {
    final service = NotificationService._internal();
    service._notificationsEnabled = enabled;
    service._isTestMode = true;
    if (plugin != null) {
      service._notificationsPlugin = plugin;
    }
    _instance = service;
    return service;
  }

  static const String prefKey = 'pref_notifications_enabled';

  static const int welcomeNotificationId = 1000;
  static const int chestReadyNotificationId = 1001;
  static const int dailyQuestsNotificationId = 1002;
  static const int streakReminderNotificationId = 1003;

  static const String payloadWelcome = 'welcome';
  static const String payloadChest = 'chest';
  static const String payloadQuests = 'quests';
  static const String payloadStreak = 'streak';

  static const String channelId = 'rewards_channel';
  static const String channelName = 'Rewards & Bonuses';
  static const String channelDescription =
      'Cooldown notifications, streak reminders, and quest alerts';

  FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final ValueNotifier<String?> selectNotificationPayload =
      ValueNotifier<String?>(null);

  bool _notificationsEnabled = true;
  bool _initialized = false;
  bool _isTestMode = false;

  bool get isNotificationsEnabled => _notificationsEnabled;

  /// Handles incoming notification tap payloads.
  void handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    selectNotificationPayload.value = payload;
  }

  /// Initializes the notification engine, timezone database, and notification channels.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _initTimeZones();
    await _loadPreference();
    await _initPluginSettings();
    await _checkAppLaunchPayload();
  }

  void _initTimeZones() {
    try {
      tz.initializeTimeZones();
      final timeZoneName = DateTime.now().timeZoneName;
      if (tz.timeZoneDatabase.locations.containsKey(timeZoneName)) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        return;
      }
      final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
      final matchingLocation = tz.timeZoneDatabase.locations.values
          .cast<tz.Location?>()
          .firstWhere(
            (loc) => loc?.currentTimeZone.offset == offsetMs,
            orElse: () => null,
          );
      if (matchingLocation != null) {
        tz.setLocalLocation(matchingLocation);
      } else {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    } catch (e) {
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
      debugPrint('NotificationService: Timezone init note: $e');
    }
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool(prefKey) ?? true;
    } catch (e) {
      debugPrint('NotificationService: Could not load preference: $e');
    }
  }

  Future<void> _initPluginSettings() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          handleNotificationPayload(response.payload);
        },
      );

      await _createAndroidChannel();
    } catch (e) {
      if (!_isTestMode) {
        debugPrint('NotificationService: Initialization note: $e');
      }
    }
  }

  Future<void> _createAndroidChannel() async {
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      const channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      await androidImplementation.createNotificationChannel(channel);
    }
  }

  Future<void> _checkAppLaunchPayload() async {
    if (_isTestMode) return;
    try {
      final launchDetails =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        handleNotificationPayload(launchDetails?.notificationResponse?.payload);
      }
    } catch (e) {
      if (!_isTestMode) {
        debugPrint('NotificationService: Check launch payload note: $e');
      }
    }
  }

  /// Requests notification permissions for Android 13+ and iOS.
  Future<bool> requestPermissions() async {
    if (_isTestMode) return true;
    try {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted =
            await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }

      final iosImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      if (!_isTestMode) {
        debugPrint('NotificationService: Permission request note: $e');
      }
    }
    return true;
  }

  /// Toggles notification preferences and updates active schedules.
  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, enabled);
    } catch (e) {
      debugPrint('NotificationService: Could not persist preference: $e');
    }

    if (!enabled) {
      await cancelAll();
    } else {
      await scheduleDailyQuestsReminder();
      await scheduleStreakReminder();
    }
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF6035EE),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Displays an immediate high-satisfaction welcome notification upon user sign-in.
  Future<void> showWelcomeNotification({String? userName}) async {
    if (!_notificationsEnabled) return;

    try {
      final name = userName != null && userName.trim().isNotEmpty
          ? ' ${userName.trim()}'
          : '';
      await _notificationsPlugin.show(
        welcomeNotificationId,
        '🎉 Welcome to RBX Rewards$name!',
        'Your 500 RBX Welcome Bonus is active! Complete daily tasks to earn more.',
        _notificationDetails(),
        payload: payloadWelcome,
      );
    } catch (e) {
      if (!_isTestMode) {
        debugPrint('NotificationService: showWelcomeNotification error: $e');
      }
    }
  }

  /// Handles complete post-sign-in notification integration:
  /// 1. Prompts for OS notification permissions (Android 13+ and iOS)
  /// 2. Enables notifications preference
  /// 3. Delivers an immediate welcome bonus notification
  /// 4. Schedules daily retention loops (Quests at 13:00, Streak at 20:00)
  Future<bool> onUserSignedIn({String? displayName}) async {
    if (!_initialized) {
      await init();
    }

    try {
      final granted = await requestPermissions();
      if (granted) {
        await setNotificationsEnabled(true);
      }
      await showWelcomeNotification(userName: displayName);
      await scheduleDailyQuestsReminder();
      await scheduleStreakReminder();
      return granted;
    } catch (e) {
      if (!_isTestMode) {
        debugPrint('NotificationService: onUserSignedIn error: $e');
      }
      return false;
    }
  }

  /// 1. Mystery Chest Ready Alert: Scheduled exactly 3 hours after user opens a chest.
  Future<void> scheduleChestReady(DateTime triggerAt) async {
    if (!_notificationsEnabled) return;
    if (triggerAt.isBefore(DateTime.now())) return;

    try {
      final scheduledDate = tz.TZDateTime.from(triggerAt, tz.local);

      await _notificationsPlugin.zonedSchedule(
        chestReadyNotificationId,
        '🎁 Your Mystery Chest is Ready!',
        'The cooldown has ended. Tap to open and claim coins!',
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payloadChest,
      );
    } catch (e) {
      if (!_isTestMode) {
        debugPrint('NotificationService: scheduleChestReady error: $e');
      }
    }
  }

  /// 2. Daily Quests Midday Reminder: Scheduled daily at 1:00 PM local time.
  Future<void> scheduleDailyQuestsReminder() async {
    if (!_notificationsEnabled) return;

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, 13, 0);

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationsPlugin.zonedSchedule(
        dailyQuestsNotificationId,
        '🎯 3 New Quests are Live!',
        'Complete your quick daily tasks to claim easy points.',
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payloadQuests,
      );
    } catch (e) {
      if (!_isTestMode) {
        debugPrint('NotificationService: scheduleDailyQuestsReminder error: $e');
      }
    }
  }

  /// 3. Streak Protector (Loss Aversion): Scheduled daily at 8:00 PM local time.
  /// If today's reward is already claimed ([isClaimedToday] = true), schedules for tomorrow.
  Future<void> scheduleStreakReminder({bool isClaimedToday = false}) async {
    if (!_notificationsEnabled) return;

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);

      if (scheduledDate.isBefore(now) || isClaimedToday) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationsPlugin.zonedSchedule(
        streakReminderNotificationId,
        '🔥 Protect Your Daily Streak!',
        "Don't lose your streak bonus! Claim your reward now.",
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payloadStreak,
      );
    } catch (e) {
      if (!_isTestMode) {
        debugPrint('NotificationService: scheduleStreakReminder error: $e');
      }
    }
  }

  /// Called immediately when a user claims their daily reward.
  /// Advances the daily streak protector notification to tomorrow at 8:00 PM.
  Future<void> onDailyRewardClaimed() async {
    await cancelStreakReminder();
    await scheduleStreakReminder(isClaimedToday: true);
  }

  /// Cancels the scheduled chest ready notification.
  Future<void> cancelChestReady() async {
    try {
      await _notificationsPlugin.cancel(chestReadyNotificationId);
    } catch (_) {}
  }

  /// Cancels the scheduled streak reminder notification.
  Future<void> cancelStreakReminder() async {
    try {
      await _notificationsPlugin.cancel(streakReminderNotificationId);
    } catch (_) {}
  }

  /// Cancels all scheduled local notifications.
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
