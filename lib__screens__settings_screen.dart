import 'package:flutter/material.dart' hide Text;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../services/sound_service.dart';
import '../core/theme.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/lock_gate.dart';
import '../widgets/name_dialog.dart';
import '../widgets/picker_sheet.dart';
import '../widgets/update_dialog.dart';
import 'about_screen.dart';
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
          const SectionTitle('Profile'),
          TileGroup(
            children: [
              ListTile(
                leading: const Icon(AppIcons.person),
                title: const Text(
                  'Your name',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: s.userName.isEmpty
                    ? const Text('Not set')
                    : Text(s.userName, verbatim: true),
                trailing: const Icon(AppIcons.chevronRight),
                onTap: () => askName(context),
              ),
            ],
          ),
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
              SwitchListTile(
                secondary: const Icon(AppIcons.volume),
                title: const Text(
                  'Sound on save',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Plays a short sound when an expense is saved',
                ),
                value: s.saveSound,
                onChanged: (on) {
                  s.setSaveSound(on);
                  if (on) SoundService.saved();
                },
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
                subtitle: const Text('Fingerprint or phone PIN'),
                value: s.appLock,
                onChanged: (on) => _toggleLock(context, s, on),
              ),
              if (s.appLock)
                ListTile(
                  leading: const Icon(AppIcons.timer),
                  title: const Text(
                    'Lock app after',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(_delayLabel(s.appLockDelay)),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: () => _pickLockDelay(context, s),
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
                      : 'Installed version: $appVersionLabel',
                ),
                onTap: () async {
                  snackInfo(context, 'Checking…');
                  final r = await UpdateService.check();
                  if (!context.mounted) return;
                  if (r.failed) {
                    snack(
                      context,
                      'Could not check for updates. Is internet on?',
                    );
                  } else if (r.update == null) {
                    snackOk(context, 'You are on the latest version.');
                  } else {
                    showUpdateDialog(context, r.update!);
                  }
                },
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
                subtitle: Text('Nothing is sent anywhere'),
              ),
            ],
          ),
          // Developer credit, the same lines as on the first intro screen.
          Padding(
            padding: const EdgeInsets.only(top: 28, bottom: 8),
            child: Column(
              children: [
                Text(
                  'Developed by',
                  verbatim: true,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Waqas Yasin',
                  verbatim: true,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Made in Pakistan',
                  verbatim: true,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
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

  static const _delays = <int, String>{
    0: 'Immediately',
    30: '30 seconds',
    60: '1 minute',
    300: '5 minutes',
    900: '15 minutes',
    -1: 'Only when app is closed',
  };

  String _delayLabel(int v) => _delays[v] ?? '30 seconds';

  Future<void> _pickLockDelay(BuildContext context, AppState s) async {
    final v = await showPickerSheet<int>(
      context,
      title: 'Lock app after',
      selected: s.appLockDelay,
      options: [
        for (final e in _delays.entries)
          PickerOption<int>(
            value: e.key,
            label: e.value,
            subtitle: e.key == 60
                ? 'Recommended'
                : e.key == -1
                    ? 'Not locked while it stays in background'
                    : null,
          ),
      ],
    );
    if (v != null) await s.setAppLockDelay(v);
  }
}
