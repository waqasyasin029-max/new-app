import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily "Have you recorded your expenses today?" reminder.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String payloadRecord = 'record_expense';
  static const int _dailyId = 1001;
  static const String _channelId = 'daily_reminder';
  static const String body = 'Have you recorded your expenses today?';

  /// Called when the user taps a notification while the app is running.
  static void Function(String? payload)? onTap;

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
    );
  }

  /// Payload of the notification that cold-started the app, if any.
  static Future<String?> launchPayload() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    if (d != null && d.didNotificationLaunchApp) {
      return d.notificationResponse?.payload;
    }
    return null;
  }

  static Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;

  static Future<bool> canScheduleExact() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  static Future<void> requestExactAlarmPermission() async {
    await _android?.requestExactAlarmsPermission();
  }

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Daily reminder',
      channelDescription: 'Reminds you to record your daily expenses',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  /// Schedules (or re-schedules) the repeating daily reminder at [time] local time.
  /// The instant is expressed in UTC so no timezone database lookup is needed;
  /// the app re-schedules on every launch so it stays correct.
  static Future<void> scheduleDaily(TimeOfDay time) async {
    await _plugin.cancel(_dailyId);
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    final exact = await canScheduleExact();
    await _plugin.zonedSchedule(
      _dailyId,
      'Kharcha Tracker',
      body,
      tz.TZDateTime.from(next, tz.UTC),
      _details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payloadRecord,
    );
  }

  static Future<void> cancel() => _plugin.cancel(_dailyId);

  static Future<void> showTest() => _plugin.show(
    1002,
    'Kharcha Tracker',
    body,
    _details,
    payload: payloadRecord,
  );
}
