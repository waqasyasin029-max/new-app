import 'package:flutter/material.dart' hide Text;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lock_gate.dart';
import '../widgets/update_dialog.dart';
import 'about_screen.dart';
import 'onboarding_screen.dart';
import 'reminders_screen.dart';
import '../core/i18n.dart';
import '../core/app_icons.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          const SectionTitle('Appearance'),
          TileGroup(
            children: [
              ListTile(
                leading: const Icon(AppIcons.brightness),
                title: const Text(
                  'Theme',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'system', label: Text('System')),
                      ButtonSegment(value: 'light', label: Text('Light')),
                      ButtonSegment(value: 'dark', label: Text('Dark')),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (v) => s.setThemeMode(v.first),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(AppIcons.translate),
                title: const Text(
                  'Language',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'ur', label: Text('اردو')),
                    ],
                    selected: {s.language},
                    onSelectionChanged: (v) => s.setLanguage(v.first),
                  ),
                ),
              ),
            ],
          ),
          const SectionTitle('Reminders'),
          TileGroup(
            children: [
              ListTile(
                leading: const Icon(AppIcons.bellRinging),
                title: const Text(
                  'Reminders',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  s.reminderEnabled
                      ? '${tr('Daily at')} ${s.reminderTime.format(context)}'
                      : tr('Off'),
                  verbatim: true,
                ),
                trailing: const Icon(AppIcons.chevronRight),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RemindersScreen()),
                ),
              ),
            ],
          ),
          const SectionTitle('Privacy'),
          TileGroup(
            children: [
              SwitchListTile(
                secondary: const Icon(AppIcons.lock),
                title: const Text(
                  'App lock',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Ask for your fingerprint or phone PIN when the app opens',
                ),
                value: s.appLock,
                onChanged: (on) => _toggleLock(context, s, on),
              ),
            ],
          ),
          const SectionTitle('App'),
          TileGroup(
            children: [
              ListTile(
                leading: const Icon(AppIcons.systemUpdate),
                title: const Text(
                  'Check for updates',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  kBuildNumber == 0
                      ? 'Development build'
                      : 'Installed version: $kBuildNumber',
                ),
                onTap: () async {
                  snack(context, 'Checking…');
                  final r = await UpdateService.check();
                  if (!context.mounted) return;
                  if (r.failed) {
                    snack(
                      context,
                      'Could not check for updates. Is internet on?',
                    );
                  } else if (r.update == null) {
                    snack(context, 'You are on the latest version.');
                  } else {
                    showUpdateDialog(context, r.update!);
                  }
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.slideshow),
                title: const Text(
                  'Show intro again',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(AppIcons.chevronRight),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OnboardingScreen(replay: true),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(AppIcons.info),
                title: const Text(
                  'About Kharcha Tracker',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(AppIcons.chevronRight),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
              const ListTile(
                leading: Icon(AppIcons.lock, color: AppColors.primary),
                title: Text(
                  'Your data stays on this phone',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Expenses and income are stored only in a local database on this phone. Nothing is sent anywhere.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Turning the lock on or off needs the phone's own unlock first, so nobody
  /// else can switch it off.
  Future<void> _toggleLock(BuildContext context, AppState s, bool on) async {
    if (on && !await DeviceLock.available()) {
      if (context.mounted) {
        snack(
          context,
          'Set a screen lock (PIN, pattern or fingerprint) on your phone first.',
        );
      }
      return;
    }
    final r = await DeviceLock.ask(
      on ? 'Turn on app lock' : 'Turn off app lock',
    );
    if (!context.mounted) return;
    if (r == DeviceLockResult.ok) {
      await s.setAppLock(on);
    } else if (r == DeviceLockResult.unavailable) {
      snack(
        context,
        'Set a screen lock (PIN, pattern or fingerprint) on your phone first.',
      );
    }
  }
}
