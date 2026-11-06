import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/voice_entry_screen.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';
import 'state/app_state.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void openRecordScreen() {
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => const VoiceEntryScreen()),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService.init();
  } catch (_) {}
  NotificationService.onTap = (payload) {
    if (payload == NotificationService.payloadRecord) openRecordScreen();
  };

  final state = AppState();
  await state.init();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const KharchaApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Re-schedule on every launch so the daily reminder always stays correct.
    await state.applyReminder();
    try {
      // App was cold-started by tapping the reminder notification.
      final payload = await NotificationService.launchPayload();
      if (payload == NotificationService.payloadRecord) openRecordScreen();
    } catch (_) {}
    _checkForUpdateOnLaunch();
  });
}

/// Quietly asks GitHub for a newer release; shows the update dialog if there is one.
Future<void> _checkForUpdateOnLaunch() async {
  final r = await UpdateService.check();
  final ctx = navigatorKey.currentState?.overlay?.context;
  if (r.update != null && ctx != null && ctx.mounted) {
    showUpdateDialog(ctx, r.update!);
  }
}

class KharchaApp extends StatelessWidget {
  const KharchaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kharcha Tracker',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: buildAppTheme(),
      builder: (context, child) => AppBackground(child: child),
      home: const HomeShell(),
    );
  }
}
