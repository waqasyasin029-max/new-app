import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'income_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.payments),
            title: const Text('Salary & income'),
            subtitle: const Text('Set or update your monthly salary'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IncomeScreen()),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Daily reminder',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active),
            title: const Text('Remind me every day'),
            subtitle: const Text('"Have you recorded your expenses today?"'),
            value: s.reminderEnabled,
            onChanged: (v) => s.setReminder(enabled: v),
          ),
          ListTile(
            enabled: s.reminderEnabled,
            leading: const Icon(Icons.access_time),
            title: const Text('Reminder time'),
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
            leading: const Icon(Icons.alarm_on),
            title: const Text('Allow exact alarms'),
            subtitle: const Text(
              'Makes the reminder arrive on the minute (Android 12+)',
            ),
            onTap: () async {
              await NotificationService.requestExactAlarmPermission();
              await s.applyReminder();
            },
          ),
          ListTile(
            leading: const Icon(Icons.notification_add),
            title: const Text('Send test notification'),
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
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Voice input',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Speaking language'),
            trailing: DropdownButton<String>(
              value: s.speechLocale,
              items: [
                for (final e in AppState.speechLocales.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => v == null ? null : s.setSpeechLocale(v),
            ),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.lock),
            title: Text('Your data stays on this phone'),
            subtitle: Text(
              'Expenses and income are stored only in a local SQLite database. '
              'Speech-to-text is performed by your phone\'s speech service.',
            ),
          ),
        ],
      ),
    );
  }
}
