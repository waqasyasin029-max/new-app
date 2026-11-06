import 'package:flutter/material.dart' hide Text;

import '../core/theme.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../logic/expense_parser.dart';
import '../services/cloud_speech_service.dart';
import '../services/speech_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'confirm_expenses_screen.dart';
import 'settings_screen.dart';
import '../core/i18n.dart';

class VoiceEntryScreen extends StatefulWidget {
  const VoiceEntryScreen({super.key});

  @override
  State<VoiceEntryScreen> createState() => _VoiceEntryScreenState();
}

class _VoiceEntryScreenState extends State<VoiceEntryScreen>
    with SingleTickerProviderStateMixin {
  final SpeechService _speech = SpeechService();
  final CloudSpeechService _cloud = CloudSpeechService();
  bool _usingCloud = false;
  bool _busy = false;
  final TextEditingController _text = TextEditingController();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _listening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    void onText(String t) {
      if (!mounted) return;
      setState(() {
        _text.text = t;
        _text.selection = TextSelection.collapsed(offset: t.length);
      });
    }

    void onListening(bool v) {
      if (!mounted) return;
      setState(() => _listening = v);
      if (v) {
        _pulse.repeat(reverse: true);
      } else {
        _pulse.stop();
        _pulse.value = 0;
      }
    }

    void onError(String m) {
      if (mounted) setState(() => _error = m);
    }

    _speech.onText = onText;
    _speech.onListening = onListening;
    _speech.onError = onError;
    _cloud.onText = onText;
    _cloud.onListening = onListening;
    _cloud.onError = onError;
    _cloud.onBusy = (v) {
      if (mounted) setState(() => _busy = v);
    };
  }

  @override
  void dispose() {
    _speech.dispose();
    _cloud.dispose();
    _pulse.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_listening) {
      await (_usingCloud ? _cloud.stop() : _speech.stop());
      return;
    }
    setState(() => _error = null);
    final app = context.read<AppState>();
    final mic = await _speech.ensureMic();
    if (mic != MicStatus.granted) {
      _permissionDialog(mic == MicStatus.permanentlyDenied);
      return;
    }
    if (app.useCloudVoice) {
      _usingCloud = true;
      await _cloud.start(
        apiKey: app.groqKey,
        localeId: app.speechLocale,
        existing: _text.text,
      );
      return;
    }
    _usingCloud = false;
    if (!await _speech.init()) {
      setState(
        () => _error = 'Speech recognition is not available on this phone. Install/enable "Speech Services by Google", or type your expenses below.',
      );
      return;
    }
    await _speech.start(
      localeId: context.read<AppState>().speechLocale,
      existing: _text.text,
    );
  }

  void _permissionDialog(bool permanent) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Microphone permission needed'),
        content: Text(
          permanent
              ? 'Microphone access was denied. Open app settings and allow Microphone to use voice entry. You can still type expenses below.'
              : 'Voice entry needs the microphone. You can still type your expenses below.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          if (permanent)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Open settings'),
            ),
        ],
      ),
    );
  }

  Future<void> _analyze() async {
    if (_listening) await (_usingCloud ? _cloud.stop() : _speech.stop());
    final text = _text.text.trim();
    if (text.isEmpty) {
      snack(context, 'Speak or type your expenses first.');
      return;
    }
    final result = ExpenseParser.parse(text);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmExpensesScreen(rawText: text, result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Record expenses')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            borderRadius: BorderRadius.circular(16),
            value: state.speechLocale,
            decoration: InputDecoration(
              labelText: tr('Speaking language'),
              isDense: true,
            ),
            items: [
              for (final e in AppState.speechLocales.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: _listening
                ? null
                : (v) => v == null ? null : state.setSpeechLocale(v),
          ),
          const SizedBox(height: 24),
          Center(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Container(
                padding: EdgeInsets.all(10 + 14 * _pulse.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (_listening ? Colors.red : AppColors.gold).withOpacity(
                    0.15,
                  ),
                ),
                child: child,
              ),
              child: Material(
                color: _listening ? Colors.red : AppColors.gold,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _busy ? null : _toggle,
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(34),
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _listening ? Icons.stop : Icons.mic,
                            size: 56,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _busy
                  ? 'Converting your voice to text…'
                  : _listening
                  ? 'Listening… tap to stop'
                  : 'Tap the mic and speak',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (state.voiceEngine == 'cloud' && state.groqKey.trim().isEmpty)
            AppCard(
              margin: const EdgeInsets.only(top: 12),
              child: ListTile(
                leading: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Want much better voice recognition?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Add a free AI voice key in Settings > Voice input.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ),
          if (_error != null)
            AppCard(
              color: scheme.errorContainer,
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: tr('What was heard (you can edit this)'),
              hintText: tr(
                'Aj 300 rupay petrol ka kharcha hua, 200 ki chai pi, 500 ki grocery ki…',
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _analyze,
            icon: const Icon(Icons.fact_check),
            label: const Text('Review expenses'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing is saved until you confirm it on the next screen. '
            'Check the text above: if a number was misheard, fix it here.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
