import 'package:flutter/material.dart' hide Text;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/notification_service.dart';
import '../services/tts_service.dart';
import '../services/update_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/update_dialog.dart';
import 'about_screen.dart';
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
              ListTile(
                enabled: s.assistantOn,
                leading: const Icon(Icons.volume_up_outlined),
                title: const Text(
                  'Hear the voice',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Plays a sample sentence with the current voice settings',
                ),
                onTap: !s.assistantOn ? null : () => _hearVoice(context, s),
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

  Future<void> _hearVoice(BuildContext context, AppState s) async {
    final tts = TtsService();
    String? note;
    tts.onNotice = (m) => note = m;
    tts.configure(
      key: s.elevenKey,
      voiceId: s.elevenVoiceId,
      model: s.elevenModel,
      enabled: s.naturalVoice,
    );
    final ok = await tts.init();
    if (!ok) {
      if (context.mounted) {
        snack(
          context,
          'Urdu text-to-speech is not installed on this phone. Install "Speech Services by Google" and its Urdu voice, then try again. Normal voice entry is used for now.',
        );
      }
      await tts.dispose();
      return;
    }
    if (!tts.cloudOn && context.mounted) {
      snack(
        context,
        'Natural voice is off or has no key, so this is the phone voice.',
      );
    }
    final name = s.userName.trim();
    await tts.speak(
      'السلام علیکم${name.isEmpty ? '' : ' $name سر'}! بتائیے، اب کتنا خرچہ ہوا؟',
    );
    if (note != null && context.mounted) snack(context, note!);
    await tts.dispose();
  }

  static const _voices = <(String, String)>[
    ('Adam (male, deep)', 'pNInz6obpgDQGcFmaJgB'),
    ('Josh (male, young)', 'TxGEqnHWrfWFTfGW9XjX'),
    ('Antoni (male, soft)', 'ErXwobaYiN019PkySvjV'),
    ('Arnold (male, strong)', 'VR6AewLTigWG4xSOukaG'),
    ('Rachel (female, calm)', '21m00Tcm4TlvDq8ikWAM'),
    ('Bella (female, soft)', 'EXAVITQu4vr4xnSDxMaL'),
    ('Elli (female, young)', 'MF3mGyEYCl7XYWbV9V6O'),
    ('Domi (female, strong)', 'AZnzlk1XvdvUeBnXmlld'),
  ];

  static const _models = <(String, String)>[
    ('Automatic (best first)', ''),
    ('Eleven v3 (most natural)', 'eleven_v3'),
    ('Multilingual v2 (stable)', 'eleven_multilingual_v2'),
    ('Turbo v2.5 (faster)', 'eleven_turbo_v2_5'),
    ('Flash v2.5 (fastest)', 'eleven_flash_v2_5'),
  ];

  Future<void> _editEleven(BuildContext context, AppState s) async {
    final key = TextEditingController(text: s.elevenKey);
    final custom = TextEditingController();
    final known = _voices.any((v) => v.$2 == s.elevenVoiceId);
    // '' means the default voice, 'custom' means the Voice ID box is used.
    var voiceSel = s.elevenVoiceId.isEmpty
        ? _voices.first.$2
        : (known ? s.elevenVoiceId : 'custom');
    if (voiceSel == 'custom') custom.text = s.elevenVoiceId;
    var modelSel = _models.any((m) => m.$2 == s.elevenModel)
        ? s.elevenModel
        : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('ElevenLabs key and voice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Sign in at elevenlabs.io.\n'
                  '2. Developers, API Keys: create a key and allow Text to Speech.\n'
                  '3. Paste it here.',
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
                const SizedBox(height: 14),
                const Text(
                  'Voice',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: voiceSel,
                  items: [
                    for (final v in _voices)
                      DropdownMenuItem(value: v.$2, child: Text(v.$1)),
                    const DropdownMenuItem(
                      value: 'custom',
                      child: Text('Other (paste Voice ID)'),
                    ),
                  ],
                  onChanged: (v) => setSt(() => voiceSel = v ?? voiceSel),
                ),
                if (voiceSel == 'custom')
                  TextField(
                    controller: custom,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      hintText: 'Voice ID from your Voices page',
                      isDense: true,
                    ),
                  ),
                const SizedBox(height: 14),
                const Text(
                  'Model',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  value: modelSel,
                  items: [
                    for (final m in _models)
                      DropdownMenuItem(value: m.$2, child: Text(m.$1)),
                  ],
                  onChanged: (v) => setSt(() => modelSel = v ?? modelSel),
                ),
                const SizedBox(height: 4),
                const Text(
                  'After saving, use "Hear the voice" to test it.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            if (s.elevenKey.isNotEmpty)
              TextButton(
                onPressed: () {
                  key.clear();
                  voiceSel = _voices.first.$2;
                  modelSel = '';
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
      ),
    );
    final k = key.text;
    final v = voiceSel == 'custom' ? custom.text.trim() : voiceSel;
    key.dispose();
    custom.dispose();
    if (ok == true) await s.setEleven(key: k, voiceId: v, model: modelSel);
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
