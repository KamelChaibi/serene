import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'storage.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        // App launched or tapped from notification
      },
    );

    _isInitialized = true;
  }

  Future<bool> requestPermission() async {
    await init();
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS || Platform.isMacOS) {
      final iosImplementation = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  Future<void> scheduleDailyCheckIn({
    required int hour,
    required int minute,
    String title = 'سكينة • Mindful Moment',
    String body = 'Take a slow, deep breath. How are you feeling right now?',
  }) async {
    await init();
    await cancelAll();

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'serene_daily_checkin',
      'Daily Wellness Check-in',
      channelDescription: 'Gentle mindful check-ins and breathing reminders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.zonedSchedule(
      id: 1001,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await Store.setString('reminder_hour', '$hour');
    await Store.setString('reminder_minute', '$minute');
    await Store.setString('reminder_enabled', 'true');
  }

  Future<void> showInstantCheckIn({
    String title = 'سكينة • Serene',
    String body = 'You are safe. Take a slow breath with me.',
  }) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'serene_instant',
      'Instant Affirmation',
      channelDescription: 'Immediate soothing affirmations and breathing cues',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _notifications.show(
      id: 1002,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelAll() async {
    await init();
    await _notifications.cancelAll();
    await Store.setString('reminder_enabled', 'false');
  }

  Future<bool> isReminderEnabled() async {
    return (await Store.getString('reminder_enabled')) == 'true';
  }

  Future<Map<String, int>> getReminderTime() async {
    final h = int.tryParse(await Store.getString('reminder_hour') ?? '20') ?? 20;
    final m = int.tryParse(await Store.getString('reminder_minute') ?? '00') ?? 0;
    return {'hour': h, 'minute': m};
  }
}

