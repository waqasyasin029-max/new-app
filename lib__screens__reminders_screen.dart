import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/app_icons.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/time_sheet.dart';

/// One reminder a day: an on/off switch and the time.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
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
                        final t = await showTimeSheet(
                          context,
                          initial: s.reminderTime,
                        );
                        if (t != null) {
                          await s.setReminder(time: t);
                          if (context.mounted)
                            snackOk(
                              context,
                              'Reminder set for ${t.format(context)} daily.',
                            );
                        }
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
