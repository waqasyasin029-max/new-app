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

  /// The daily reminder is scheduled as one notification per day for the next
  /// [_rotationDays] days (ids [_rotationBase] and up), each with a different
  /// light-hearted line. The app re-schedules on every launch, so the window
  /// always moves forward.
  static const int _rotationBase = 2000;
  static const int _rotationDays = 30;
  static const String _channelId = 'daily_reminder';
  static const String _bodyEn = 'Have you recorded your expenses today?';
  static String get body => tr(_bodyEn);

  static const List<String> _dailyLines = [
    'آج کتنے پیسے اڑائے؟ ذرا حساب تو لکھ دیں! 😄',
    'بٹوہ پوچھ رہا ہے: آج مجھے کہاں کہاں لے کر گئے تھے؟ 👛',
    'کھاتا خالی رہا تو بجٹ رو دے گا، جلدی سے خرچے لکھ دیں! 😅',
    'چائے، سموسے، رکشہ... سب لکھ لیا یا کچھ بھول گئے؟ 🫖',
    'آج کا خرچہ آج ہی لکھ دیں، کل آپ کو کچھ یاد نہیں رہے گا! 🤭',
    'پیسے تو ہنس کے خرچ کر دیے، اب حساب بھی ہنس کے لکھ دیں! 😁',
    'بس ایک منٹ کا کام ہے! خرچے لکھیں اور سکون سے سوئیں۔ 😴',
    'سنیں! آپ کا کھاتا اداس بیٹھا ہے، اسے آج کے خرچے سنا دیں۔ 🥺',
    'سنا ہے آج بازار گئے تھے؟ رسید نکالیں اور لکھ دیں! 🧾',
    'آج جیب ہلکی ہوئی؟ وجہ لکھ دیں تاکہ کل سمجھ آ جائے۔ 🤔',
    'بریکنگ نیوز: آج کے خرچے ابھی تک درج نہیں ہوئے! 📰',
    'پیسے کہاں گئے؟ خرچہ ٹریکر کو بتا دیں، یہ کسی کو نہیں بتائے گا! 🕵️',
    'بریانی کی پلیٹ تو یاد ہے، اس کا بل بھی لکھ دیں! 🍛',
    'آج کوئی شاپنگ کی؟ بٹوے کی آہیں سنائی دے رہی ہیں۔ 🛍️',
    'خرچے لکھ لیں، مہینے کے آخر میں حیران ہونے سے بچ جائیں گے! 😮',
    'ایک چھوٹا سا کام: آج کے خرچے لکھ دیں۔ انعام: بے فکر نیند! 🎁',
    'کھاتے والے انکل پوچھ رہے ہیں: بیٹا، آج کا حساب؟ 👴',
    'رکشے والے کو تو پیسے دے دیے، ایپ کو بھی خبر دے دیں! 🛺',
    'آپ کی جیب کا سی سی ٹی وی کہتا ہے: آج کچھ خرچ ہوا ہے! 📹',
    'چائے ٹھنڈی ہونے سے پہلے خرچے لکھ دیں! ☕',
    'آج کا حساب ابھی لکھ لیں، ورنہ رات کو خواب میں رسیدیں آئیں گی! 👻',
    'پیسہ آتا جاتا رہتا ہے، پر لکھا ہوا حساب ہمیشہ رہتا ہے! 📒',
    'آج کتنی بار "بس ایک اور" کہہ کر خرچ کیا؟ لکھ دیں، شرمانا نہیں! 😆',
    'موبائل ہاتھ میں ہے ہی، تو دو منٹ خرچے بھی لکھ لیں! 📱',
    'بٹوہ کہہ رہا ہے: میں نے آج بہت محنت کی، اب آپ حساب لکھ دیں! 💪',
    'آج کے خرچے لکھ کر خود کو شاباش دیں، آپ تو بجٹ کے ہیرو ہیں! 🦸',
    'کوئی چھوٹا خرچہ بھول تو نہیں گئے؟ چھوٹے چھوٹے خرچے ہی بڑا بل بنتے ہیں! 🔍',
    'ٹِک ٹِک! دن ختم ہونے والا ہے اور خرچے ابھی تک نہیں لکھے! ⏰',
    'آج بچت ہوئی یا جیب نے الوداع کہہ دیا؟ جو بھی ہو، لکھ دیں! 👋',
    'آج دوستوں کو چائے پلائی؟ حساب لکھ لیں، دل بڑا رکھیں! 🫶',
  ];

  /// The line for a given day: a fixed rotation, so every day reads
  /// differently and the same date always gets the same line.
  static String _lineFor(DateTime day) {
    final n = DateTime.utc(day.year, day.month, day.day)
        .difference(DateTime.utc(2024, 1, 1))
        .inDays;
    return _dailyLines[n % _dailyLines.length];
  }

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

  /// The reminder's title is always Urdu, whatever the app language is.
  static const String _title = 'آج کا حساب لکھا؟';

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Daily reminder',
      channelDescription: 'Reminds you to record your daily expenses',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      color: Color(0xFFEE6F2B),
      largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
    ),
  );

  /// Same look as [_details], with the whole line readable when expanded.
  static NotificationDetails _detailsFor(String line) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Daily reminder',
      channelDescription: 'Reminds you to record your daily expenses',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      color: const Color(0xFFEE6F2B),
      largeIcon: const DrawableResourceAndroidBitmap('ic_notification_large'),
      styleInformation: BigTextStyleInformation(line),
    ),
  );

  /// Schedules (or re-schedules) the daily reminder at [time] local time:
  /// one notification for each of the next [_rotationDays] days, each with
  /// its own funny line. The instant is expressed in UTC so no timezone
  /// database lookup is needed.
  static Future<void> scheduleDaily(TimeOfDay time) async {
    await cancel();
    final now = DateTime.now();
    var first = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!first.isAfter(now)) {
      first = DateTime(now.year, now.month, now.day + 1, time.hour, time.minute);
    }
    final exact = await canScheduleExact();
    try {
      for (var i = 0; i < _rotationDays; i++) {
        final when = DateTime(
          first.year,
          first.month,
          first.day + i,
          time.hour,
          time.minute,
        );
        final line = _lineFor(when);
        await _plugin.zonedSchedule(
          _rotationBase + i,
          _title,
          line,
          tz.TZDateTime.from(when, tz.UTC),
          _detailsFor(line),
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payloadRecord,
        );
      }
    } catch (e) {
      lastError = '$e';
      rethrow;
    }
  }

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
      final days = pending
          .where(
            (p) =>
                p.id == _dailyId ||
                (p.id >= _rotationBase && p.id < _rotationBase + _rotationDays),
          )
          .length;
      count = days == 0 ? '0' : '1 daily ($days days ahead)';
    } catch (e) {
      count = 'unknown ($e)';
    }
    final err = lastError == null ? '' : '\nError: $lastError';
    return 'Notifications allowed: $allowed\n'
        'Exact alarms: $exact\n'
        'Reminders scheduled: $count$err';
  }

  static Future<void> cancelId(int id) => _plugin.cancel(id);

  static Future<void> cancel() async {
    await _plugin.cancel(_dailyId);
    for (var i = 0; i < _rotationDays; i++) {
      await _plugin.cancel(_rotationBase + i);
    }
  }

  static Future<void> showTest() => _plugin.show(
    1002,
    _title,
    _lineFor(DateTime.now()),
    _detailsFor(_lineFor(DateTime.now())),
    payload: payloadRecord,
  );
}
