import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Wraps `flutter_local_notifications` for SketchDaily's single channel.
///
/// There is exactly one channel, `sketchdaily_reminders`, used for the daily
/// "time to sketch" nudge. We intentionally use inexact-periodic scheduling
/// (`AndroidScheduleMode.inexactAllowWhileIdle`) so we don't have to request
/// the Android 14 `SCHEDULE_EXACT_ALARM` permission — a ~minute of jitter
/// on a habit reminder is acceptable.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String channelId = 'sketchdaily_reminders';
  static const String channelName = 'Daily Sketch Reminders';
  static const String channelDescription = 'Daily reminder to do your SketchDaily session.';

  static const int _dailyReminderId = 1001;
  static const String _reminderTitle = 'Time to sketch';
  static const String _reminderBody = "Five minutes and a pencil. Let's keep the streak going.";

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    // tz.local defaults to UTC until explicitly set — detect the device timezone.
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const androidInit = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  /// Android 13+ (SDK 33) requires runtime notification permission.
  Future<bool> requestPermissionsIfNeeded() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await cancelDailyReminder();
    final scheduled = _nextInstanceOf(hour: hour, minute: minute);

    await _plugin.zonedSchedule(
      _dailyReminderId,
      _reminderTitle,
      _reminderBody,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelDailyReminder() async {
    await _plugin.cancel(_dailyReminderId);
  }

  /// Debug-only: fires a single immediate notification using the same channel
  /// the daily reminder uses. Lets us verify channel/icon/permission without
  /// waiting for a scheduled trigger.
  Future<void> showTestNotification() async {
    await _plugin.show(
      9999,
      _reminderTitle,
      _reminderBody,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Debug-only: schedule a reminder a fixed number of seconds from now,
  /// so we can watch the real scheduler fire without waiting a full day.
  Future<void> scheduleDebugReminderIn({required Duration delay}) async {
    await _plugin.cancel(_dailyReminderId);
    final scheduled = tz.TZDateTime.now(tz.local).add(delay);
    await _plugin.zonedSchedule(
      _dailyReminderId,
      _reminderTitle,
      'Debug — scheduled via scheduleDebugReminderIn.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _nextInstanceOf({required int hour, required int minute}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
