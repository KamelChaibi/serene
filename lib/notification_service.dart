import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'storage.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  static const String defaultTitle = 'Serene • Mindful Moment';
  static const String defaultBody =
      'Take a slow, deep breath. How are you feeling right now?';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    _useDeviceLocalTimeZone();

    const androidSettings =
        AndroidInitializationSettings('ic_notification');
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

    if (Platform.isAndroid) {
      final androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      const dailyChannel = AndroidNotificationChannel(
        'serene_daily_checkin',
        'Daily Wellness Check-in',
        description: 'Gentle mindful check-ins and breathing reminders',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      const instantChannel = AndroidNotificationChannel(
        'serene_instant',
        'Instant Affirmation',
        description: 'Immediate soothing affirmations and breathing cues',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      await androidImplementation?.createNotificationChannel(dailyChannel);
      await androidImplementation?.createNotificationChannel(instantChannel);
    }

    _isInitialized = true;
  }

  /// `timezone` starts in UTC, which made a "20:00" reminder fire at 20:00 UTC
  /// (21:00 in Tunis, 22:00 in Paris). Build a fixed-offset location from the
  /// device's current offset. The name is an ISO offset that Android's
  /// `ZoneId.of` understands, and because we re-schedule on every launch the
  /// offset is refreshed after a daylight-saving or travel change.
  void _useDeviceLocalTimeZone() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    if (offset == Duration.zero) {
      tz.setLocalLocation(tz.UTC);
      return;
    }

    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes < 0 ? '-' : '+';
    final absolute = totalMinutes.abs();
    final hours = (absolute ~/ 60).toString().padLeft(2, '0');
    final minutes = (absolute % 60).toString().padLeft(2, '0');
    final name = '$sign$hours:$minutes';

    final zone = tz.TimeZone(
      offset,
      isDst: false,
      abbreviation: now.timeZoneName,
    );
    tz.setLocalLocation(
      tz.Location(name, <int>[tz.minTime], <int>[0], <tz.TimeZone>[zone]),
    );
  }

  Future<bool> requestPermission() async {
    await init();
    if (kIsWeb) return false;

    try {
      if (Platform.isAndroid) {
        final androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation == null) return false;

        // Asking again after the user already granted it is a no-op on some
        // Android versions and returns null, which used to leave the reminder
        // switch stuck off. Check the current state first.
        final already = await androidImplementation.areNotificationsEnabled();
        if (already != true) {
          final granted =
              await androidImplementation.requestNotificationsPermission();
          if (granted != true) return false;
        }

        // Check if exact alarms can be scheduled; request permission if needed on Android 13/14+
        try {
          final canExact =
              await androidImplementation.canScheduleExactNotifications();
          if (canExact != true) {
            await androidImplementation.requestExactAlarmsPermission();
          }
        } catch (_) {
          // Failure to request exact alarm is non-blocking (falls back to inexact)
        }

        return true;
      } else if (Platform.isIOS || Platform.isMacOS) {
        final iosImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } on PlatformException catch (_) {
      return false;
    }
    return true;
  }

  Future<bool> areNotificationsEnabled() async {
    await init();
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final implementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        return await implementation?.areNotificationsEnabled() ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> scheduleDailyCheckIn({
    required int hour,
    required int minute,
    String title = defaultTitle,
    String body = defaultBody,
  }) async {
    await init();
    await _schedule(hour: hour, minute: minute, title: title, body: body);

    await Store.setString('reminder_hour', '$hour');
    await Store.setString('reminder_minute', '$minute');
    await Store.setString('reminder_title', title);
    await Store.setString('reminder_body', body);
    await Store.setString('reminder_enabled', 'true');
  }

  /// Re-creates the daily schedule on start-up so a timezone or DST change is
  /// picked up even if the user never opens the reminder settings again.
  Future<void> restoreScheduleIfEnabled() async {
    await init();
    if (!await isReminderEnabled()) return;

    final time = await getReminderTime();
    final title = await Store.getString('reminder_title') ?? defaultTitle;
    final body = await Store.getString('reminder_body') ?? defaultBody;
    await _schedule(
      hour: time['hour']!,
      minute: time['minute']!,
      title: title,
      body: body,
    );
  }

  Future<void> _schedule({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    // Only this app's notifications are replaced; the enabled flag is left
    // alone so a failed schedule cannot silently report "on".
    await _notifications.cancelAll();

    final now = DateTime.now();
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    var scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (Platform.isAndroid) {
      try {
        final androidImplementation =
            _notifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final canExact =
            await androidImplementation?.canScheduleExactNotifications();
        if (canExact == true) {
          scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
        }
      } catch (_) {}
    }

    const androidDetails = AndroidNotificationDetails(
      'serene_daily_checkin',
      'Daily Wellness Check-in',
      channelDescription: 'Gentle mindful check-ins and breathing reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
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
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> showInstantCheckIn({
    String title = 'Serene',
    String body = 'You are safe. Take a slow breath with me.',
  }) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'serene_instant',
      'Instant Affirmation',
      channelDescription: 'Immediate soothing affirmations and breathing cues',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _notifications.show(
      id: 1002,
      title: title,
      body: body,
      notificationDetails: details,
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
    final h =
        int.tryParse(await Store.getString('reminder_hour') ?? '20') ?? 20;
    final m =
        int.tryParse(await Store.getString('reminder_minute') ?? '00') ?? 0;
    return {'hour': h, 'minute': m};
  }
}
