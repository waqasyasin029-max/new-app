import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';

/// The notice the developer sends from the Kharcha Notice app.
const String _noticeUrl =
    'https://raw.githubusercontent.com/waqasyasin029-max/kharcha-notices/main/latest.json';
const String _taskName = 'kharcha_notice_check';
const String _seenKey = 'notice_seen_id';

/// Runs in the background (even when the app is closed).
@pragma('vm:entry-point')
void announceDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await AnnounceService.checkAndShow();
    } catch (_) {}
    return true;
  });
}

class AnnounceService {
  /// Checks for a new notice every couple of hours, app open or not.
  static Future<void> schedule() async {
    try {
      await Workmanager().initialize(announceDispatcher);
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: const Duration(hours: 2),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {}
  }

  /// Shows the current notice once per phone. Never throws.
  static Future<void> checkAndShow() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(_noticeUrl));
      req.headers.set('User-Agent', 'kharcha-tracker');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final j = jsonDecode(await res.transform(utf8.decoder).join());
      if (j is! Map<String, dynamic> || j['active'] != true) return;
      final id = '${j['id'] ?? ''}';
      final title = '${j['title'] ?? ''}'.trim();
      final body = '${j['body'] ?? ''}'.trim();
      if (id.isEmpty || title.isEmpty || body.isEmpty) return;
      final exp = DateTime.tryParse('${j['expires'] ?? ''}');
      if (exp != null) {
        final now = DateTime.now();
        if (DateTime(exp.year, exp.month, exp.day).isBefore(DateTime(now.year, now.month, now.day))) {
          return;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_seenKey) == id) return;
      await NotificationService.init();
      await NotificationService.showNotice(title, body);
      await prefs.setString(_seenKey, id);
    } catch (_) {
    } finally {
      client.close(force: true);
    }
  }
}
