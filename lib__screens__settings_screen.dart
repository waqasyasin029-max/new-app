import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/update_dialog.dart';
import 'income_screen.dart';

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
          TileGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text(
                  'Salary & income',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Set or update your monthly salary'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IncomeScreen()),
                ),
              ),
            ],
          ),
          const SectionTitle('Daily reminder'),
          TileGroup(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text(
                  'Remind me every day',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  '"Have you recorded your expenses today?"',
                ),
                value: s.reminderEnabled,
                onChanged: (v) => s.setReminder(enabled: v),
              ),
              ListTile(
                enabled: s.reminderEnabled,
                leading: const Icon(Icons.access_time),
                title: const Text(
                  'Reminder time',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(s.reminderTime.format(context)),
                onTap: !s.reminderEnabled
                    ? null
                    : () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: s.reminderTime,
                        );
                        if (t != null) {
                          await s.setReminder(time: t);
                          if (context.mounted)
                            snack(
                              context,
                              'Reminder set for ${t.format(context)} daily.',
                            );
                        }
                      },
              ),
              ListTile(
                leading: const Icon(Icons.alarm_on_outlined),
                title: const Text(
                  'Allow exact alarms',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Makes the reminder arrive on the minute (Android 12+)',
                ),
                onTap: () async {
                  await NotificationService.requestExactAlarmPermission();
                  await s.applyReminder();
                },
              ),
              ListTile(
                leading: const Icon(Icons.notification_add_outlined),
                title: const Text(
                  'Send test notification',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  final ok = await NotificationService.requestPermission();
                  if (!ok && context.mounted) {
                    snack(
                      context,
                      'Notification permission is off. Enable it in Android settings.',
                    );
                    return;
                  }
                  await NotificationService.showTest();
                },
              ),
            ],
          ),
          const SectionTitle('Voice input'),
          TileGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text(
                  'Speaking language',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: DropdownButton<String>(
                  value: s.speechLocale,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final e in AppState.speechLocales.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => v == null ? null : s.setSpeechLocale(v),
                ),
              ),
            ],
          ),
          const SectionTitle('App'),
          TileGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.system_update_outlined),
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
              const ListTile(
                leading: Icon(Icons.lock_outline, color: AppColors.primary),
                title: Text(
                  'Your data stays on this phone',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Expenses and income are stored only in a local SQLite database. '
                  'Speech-to-text is performed by your phone\'s speech service.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
