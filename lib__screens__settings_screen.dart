import 'package:flutter/material.dart' hide Text;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/update_dialog.dart';
import 'about_screen.dart';
import 'gemini_voice_screen.dart';
import 'onboarding_screen.dart';
import 'income_screen.dart';
import '../core/i18n.dart';

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
          const SectionTitle('Appearance'),
          TileGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
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
                leading: const Icon(Icons.translate),
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
                leading: const Icon(Icons.battery_saver_outlined),
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
                leading: const Icon(Icons.timer_outlined),
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
                    snack(context, 'A test reminder will arrive in 1 minute.');
                  }
                },
              ),
              const _ReminderStatusTile(),
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
          const SectionTitle('Meal reminders'),
          TileGroup(
            children: [
              ..._mealTiles(
                context,
                s,
                meal: 'breakfast',
                title: 'Breakfast reminder',
                icon: Icons.free_breakfast_outlined,
                enabled: s.breakfastEnabled,
                time: s.breakfastTime,
              ),
              ..._mealTiles(
                context,
                s,
                meal: 'dinner',
                title: 'Dinner reminder',
                icon: Icons.dinner_dining_outlined,
                enabled: s.dinnerEnabled,
                time: s.dinnerTime,
              ),
            ],
          ),
          const SectionTitle('Voice input'),
          TileGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: const Text(
                  'Voice engine',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'cloud', label: Text('AI (better)')),
                      ButtonSegment(value: 'phone', label: Text('Phone')),
                    ],
                    selected: {s.voiceEngine},
                    onSelectionChanged: (v) => s.setVoiceEngine(v.first),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: const Text(
                  'AI voice key',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  s.groqKey.trim().isEmpty
                      ? 'Not added yet. Tap to add a free key'
                      : 'Key saved on this phone',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editKey(context, s),
              ),
              ListTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: const Text(
                  'Gemini voice test',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Hear Google\'s voices speak Urdu (free key from Google AI Studio)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GeminiVoiceScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text(
                  'Speaking language',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: DropdownButton<String>(
                  borderRadius: BorderRadius.circular(16),
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
              ListTile(
                leading: const Icon(Icons.slideshow_rounded),
                title: const Text(
                  'Show intro again',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OnboardingScreen(replay: true),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text(
                  'About Kharcha Tracker',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
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

  Future<void> _editKey(BuildContext context, AppState s) async {
    final c = TextEditingController(text: s.groqKey);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI voice key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Open console.groq.com in your browser and sign in.\n'
              '2. Go to API Keys and create a key (free).\n'
              '3. Copy it and paste it here.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                hintText: 'gsk_...',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          if (s.groqKey.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (result != null) await s.setGroqKey(result);
  }

  /// A switch row plus a time row for one meal reminder.
  List<Widget> _mealTiles(
    BuildContext context,
    AppState s, {
    required String meal,
    required String title,
    required IconData icon,
    required bool enabled,
    required TimeOfDay time,
  }) {
    return [
      SwitchListTile(
        secondary: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(time.format(context)),
        value: enabled,
        onChanged: (v) => s.setMealReminder(meal, enabled: v),
      ),
      ListTile(
        enabled: enabled,
        leading: const Icon(Icons.access_time),
        title: const Text(
          'Reminder time',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(time.format(context)),
        onTap: !enabled
            ? null
            : () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: time,
                );
                if (t != null) {
                  await s.setMealReminder(meal, time: t);
                  if (context.mounted) {
                    snack(
                      context,
                      'Reminder set for ${t.format(context)} daily.',
                    );
                  }
                }
              },
      ),
    ];
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
        leading: const Icon(Icons.fact_check_outlined),
        title: const Text(
          'Reminder status',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          snap.data == null ? '…' : _lines(snap.data!),
          verbatim: true,
        ),
        trailing: const Icon(Icons.refresh),
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
