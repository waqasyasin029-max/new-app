import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/update_dialog.dart';
import 'about_screen.dart';
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
              SwitchListTile(
                secondary: const Icon(Icons.record_voice_over_outlined),
                title: const Text(
                  'Talking assistant',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Greets you, listens, repeats your order and asks you to confirm',
                ),
                value: s.assistantOn,
                onChanged: (v) => s.setAssistantOn(v),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.graphic_eq_rounded),
                title: const Text(
                  'Natural voice (ElevenLabs)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  s.elevenKey.trim().isEmpty
                      ? 'Human-like voice. Add your ElevenLabs key below.'
                      : 'The assistant speaks with a natural voice. Without internet it uses the phone voice.',
                ),
                value: s.naturalVoice,
                onChanged: s.assistantOn ? (v) => s.setNaturalVoice(v) : null,
              ),
              ListTile(
                enabled: s.assistantOn && s.naturalVoice,
                leading: const Icon(Icons.vpn_key_outlined),
                title: const Text(
                  'ElevenLabs key and voice',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  s.elevenKey.trim().isEmpty
                      ? 'Not added yet. Tap to add'
                      : 'Key saved on this phone',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: !(s.assistantOn && s.naturalVoice)
                    ? null
                    : () => _editEleven(context, s),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.psychology_outlined),
                title: const Text(
                  'Smart conversation (AI)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Talks naturally like a person and understands any way you say it. Needs the AI key. What you say and the needed expense details are sent to Groq.',
                ),
                value: s.smartAgent,
                onChanged: s.assistantOn ? (v) => s.setSmartAgent(v) : null,
              ),
              ListTile(
                enabled: s.assistantOn,
                leading: const Icon(Icons.badge_outlined),
                title: const Text(
                  'Assistant name',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  s.userName.isEmpty ? '—' : s.userName,
                  verbatim: true,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: !s.assistantOn ? null : () => _editName(context, s),
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

  Future<void> _editName(BuildContext context, AppState s) async {
    final c = TextEditingController(text: s.userName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assistant name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The assistant calls you by this name. Write it in Urdu so it is pronounced correctly.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'وقاص',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
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
    if (result != null) await s.setUserName(result);
  }

  Future<void> _editEleven(BuildContext context, AppState s) async {
    final key = TextEditingController(text: s.elevenKey);
    final voice = TextEditingController(text: s.elevenVoiceId);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ElevenLabs key and voice'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Sign in at elevenlabs.io.\n'
                '2. Developers, API Keys: create a key and allow Text to Speech.\n'
                '3. Paste it here.\n'
                'Optional: paste a Voice ID from your Voices page to change the voice. Leave it empty for the default.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: key,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  hintText: 'API key',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: voice,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  hintText: 'Voice ID (optional)',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (s.elevenKey.isNotEmpty)
            TextButton(
              onPressed: () {
                key.clear();
                voice.clear();
                Navigator.pop(ctx, true);
              },
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final k = key.text, v = voice.text;
    key.dispose();
    voice.dispose();
    if (ok == true) await s.setEleven(key: k, voiceId: v);
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
