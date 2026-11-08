import 'package:flutter/material.dart' hide Text;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/app_icons.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// One reminder a day. Fixes for a reminder that does not arrive are tucked
/// away in a section that is closed until needed.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          const SectionTitle('Every day'),
          TileGroup(
            children: [
              SwitchListTile(
                secondary: const Icon(AppIcons.bellRinging),
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
                leading: const Icon(AppIcons.clock),
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
            ],
          ),
          const SizedBox(height: 18),
          TileGroup(
            children: [
              ListTile(
                leading: const Icon(AppIcons.alarm),
                title: const Text(
                  'Reminder not coming?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Fix it in a few taps'),
                trailing: AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(AppIcons.chevronRight),
                ),
                onTap: () => setState(() => _open = !_open),
              ),
              if (_open) ...[
                ListTile(
                  leading: const Icon(AppIcons.alarm),
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
                  leading: const Icon(AppIcons.batterySaver),
                  title: const Text(
                    'Allow background running',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Stops the phone battery saver from blocking reminders',
                  ),
                  onTap: () => Permission.ignoreBatteryOptimizations.request(),
                ),
                ListTile(
                  leading: const Icon(AppIcons.timer),
                  title: const Text(
                    'Test reminder in 1 minute',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Tap, then lock the phone and wait. It should ring on time.',
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
                    await NotificationService.scheduleTestIn(
                      const Duration(minutes: 1),
                    );
                    if (context.mounted) {
                      snack(
                        context,
                        'A test reminder will arrive in 1 minute.',
                      );
                    }
                  },
                ),
                const _ReminderStatusTile(),
                ListTile(
                  leading: const Icon(AppIcons.bellAdd),
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
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows whether reminders are really set up, and any error.
class _ReminderStatusTile extends StatefulWidget {
  const _ReminderStatusTile();

  @override
  State<_ReminderStatusTile> createState() => _ReminderStatusTileState();
}

class _ReminderStatusTileState extends State<_ReminderStatusTile> {
  late Future<String> _status = NotificationService.status();

  Future<void> _refresh() async {
    await context.read<AppState>().applyReminder();
    if (mounted) setState(() => _status = NotificationService.status());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _status,
      builder: (context, snap) => ListTile(
        leading: const Icon(AppIcons.factCheck),
        title: const Text(
          'Reminder status',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          snap.data == null ? '…' : _lines(snap.data!),
          verbatim: true,
        ),
        trailing: const Icon(AppIcons.refresh),
        onTap: _refresh,
      ),
    );
  }

  /// Translates each status line when the app is in Urdu.
  String _lines(String raw) => raw
      .split('\n')
      .map((l) {
        final i = l.indexOf(': ');
        if (i < 0) return tr(l);
        return '${tr(l.substring(0, i))}: ${tr(l.substring(i + 2))}';
      })
      .join('\n');
}
