import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/ur_strings.dart' show urExact;

/// Daily "Have you recorded your expenses today?" reminder.
class NotificationService {
  /// Notifications are always shown in Urdu, whatever the app language is.
  static String tr(String english) => urExact[english] ?? english;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String payloadRecord = 'record_expense';

  /// Last scheduling error, shown in Settings so a failure is never silent.
  static String? lastError;
  static const int _dailyId = 1001;
  static const String _channelId = 'daily_reminder';
  static const String _bodyEn = 'Have you recorded your expenses today?';
  static String get body => tr(_bodyEn);

  // Meal reminders (light-hearted on purpose).
  static const int breakfastId = 1003;
  static const int dinnerId = 1004;
  static const String _breakfastTitle = 'Breakfast time';
  static const String _breakfastBodyEn =
      'Had breakfast? Add what it cost, your wallet wants to know! 😄';
  static const String _dinnerTitle = 'Dinner time';
  static const String _dinnerBodyEn =
      'Dinner done? Belly is full, now fill the khata too! 😄';
  static String get breakfastTitle => tr(_breakfastTitle);
  static String get breakfastBody => tr(_breakfastBodyEn);
  static String get dinnerTitle => tr(_dinnerTitle);
  static String get dinnerBody => tr(_dinnerBodyEn);

  /// Called when the user taps a notification while the app is running.
  static void Function(String? payload)? onTap;

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
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
      icon: 'ic_notification',
    ),
  );

  /// Schedules (or re-schedules) the repeating daily reminder at [time] local time.
  /// The instant is expressed in UTC so no timezone database lookup is needed;
  /// the app re-schedules on every launch so it stays correct.
  static Future<void> scheduleDaily(TimeOfDay time) => scheduleAt(
    id: _dailyId,
    time: time,
    title: tr('Kharcha Tracker'),
    text: body,
  );

  /// Repeats every day at [time]; re-scheduling the same [id] replaces it.
  static Future<void> scheduleAt({
    required int id,
    required TimeOfDay time,
    required String title,
    required String text,
  }) async {
    await _plugin.cancel(id);
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    final exact = await canScheduleExact();
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        text,
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
    } catch (e) {
      lastError = '$e';
      rethrow;
    }
  }

  /// One-off reminder [after] from now, to prove that alarms really fire.
  static Future<void> scheduleTestIn(Duration after) async {
    final exact = await canScheduleExact();
    await _plugin.zonedSchedule(
      1005,
      tr('Kharcha Tracker'),
      tr('Test reminder'),
      tz.TZDateTime.from(DateTime.now().add(after), tz.UTC),
      _details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payloadRecord,
    );
  }

  /// Plain-words state of the reminders: allowed, exact, how many scheduled.
  /// Each check runs on its own, so one failing never hides the others.
  static Future<String> status() async {
    String allowed;
    try {
      allowed = (await _android?.areNotificationsEnabled() ?? true)
          ? 'yes'
          : 'NO';
    } catch (e) {
      allowed = 'unknown ($e)';
    }
    String exact;
    try {
      exact = (await canScheduleExact()) ? 'yes' : 'no';
    } catch (e) {
      exact = 'unknown ($e)';
    }
    String count;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      final ids = {for (final p in pending) p.id};
      count =
          '${ids.where((i) => i == _dailyId || i == breakfastId || i == dinnerId).length}';
    } catch (e) {
      count = 'unknown ($e)';
    }
    final err = lastError == null ? '' : '\nError: $lastError';
    return 'Notifications allowed: $allowed\n'
        'Exact alarms: $exact\n'
        'Reminders scheduled: $count$err';
  }

  static Future<void> cancelId(int id) => _plugin.cancel(id);

  static Future<void> cancel() => _plugin.cancel(_dailyId);

  static Future<void> showTest() => _plugin.show(
    1002,
    tr('Kharcha Tracker'),
    body,
    _details,
    payload: payloadRecord,
  );
}
