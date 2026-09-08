import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The daily study reminder.
///
/// This is a genuine upgrade over the web build, which could only fire while a
/// tab was open because a static PWA has no push server. A native local
/// notification fires whether or not the app is running, so the reminder
/// actually works.
///
/// The "already studied today" suppression cannot be expressed inside a
/// repeating trigger, so instead the app cancels the pending notification the
/// moment the first word of the day is learned, and re-arms it on next launch.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const int dailyReminderId = 1001;
  static const String _channelId = 'daily_reminder';
  static const String _channelName = 'Daily study reminder';
  static const String _channelDescription =
      'A once-a-day nudge to study, at the time you choose.';

  /// Set by the app so a notification tap can route into the Learn tab.
  static void Function(String? payload)? onTap;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {
      // Fall back to UTC; scheduling still works, just not in local time.
    }

    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwin = DarwinInitializationSettings(
      // Permission is requested explicitly when the user enables reminders, so
      // the prompt has context rather than firing on first launch.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
      onDidReceiveNotificationResponse: (NotificationResponse r) =>
          onTap?.call(r.payload),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.defaultImportance,
        ));

    _ready = true;
  }

  /// Asks for permission. Returns false when the user declines, so the caller
  /// can leave the setting off rather than pretending it worked.
  Future<bool> requestPermission() async {
    await init();
    if (Platform.isIOS) {
      final bool? granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<bool> hasPermission() async {
    await init();
    if (Platform.isAndroid) {
      final bool? enabled = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      return enabled ?? false;
    }
    return true;
  }

  /// Schedules the repeating daily reminder at local [hour]:[minute].
  ///
  /// Uses an inexact daily repeat, which avoids the `SCHEDULE_EXACT_ALARM`
  /// permission that Play scrutinises — a study nudge does not need
  /// to-the-second precision.
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await init();
    await cancel();

    await _plugin.zonedSchedule(
      dailyReminderId,
      title,
      body,
      _nextInstanceOf(hour, minute),
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          // A monochrome silhouette; Android cannot use the colour badge.
          icon: '@drawable/ic_notification',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'learn',
    );
  }

  /// Cancels today's pending reminder. Called when the user learns their first
  /// word of the day, so they are never nudged for work already done.
  Future<void> cancel() async {
    await init();
    await _plugin.cancel(dailyReminderId);
  }

  /// The device's IANA timezone name, shown in the reminder settings note.
  Future<String> localTimezone() async {
    try {
      return await FlutterTimezone.getLocalTimezone();
    } catch (_) {
      return '';
    }
  }

  static tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next;
  }
}
