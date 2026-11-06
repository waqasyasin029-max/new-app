import 'package:flutter/material.dart';

import '../core/theme.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../logic/expense_parser.dart';
import '../services/speech_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'confirm_expenses_screen.dart';

class VoiceEntryScreen extends StatefulWidget {
  const VoiceEntryScreen({super.key});

  @override
  State<VoiceEntryScreen> createState() => _VoiceEntryScreenState();
}

class _VoiceEntryScreenState extends State<VoiceEntryScreen>
    with SingleTickerProviderStateMixin {
  final SpeechService _speech = SpeechService();
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
    _speech.onText = (t) {
      if (!mounted) return;
      setState(() {
        _text.text = t;
        _text.selection = TextSelection.collapsed(offset: t.length);
      });
    };
    _speech.onListening = (v) {
      if (!mounted) return;
      setState(() => _listening = v);
      if (v) {
        _pulse.repeat(reverse: true);
      } else {
        _pulse.stop();
        _pulse.value = 0;
      }
    };
    _speech.onError = (m) {
      if (mounted) setState(() => _error = m);
    };
  }

  @override
  void dispose() {
    _speech.dispose();
    _pulse.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    setState(() => _error = null);
    final mic = await _speech.ensureMic();
    if (mic != MicStatus.granted) {
      _permissionDialog(mic == MicStatus.permanentlyDenied);
      return;
    }
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
    if (_listening) await _speech.stop();
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
            value: state.speechLocale,
            decoration: const InputDecoration(
              labelText: 'Speaking language',
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
                  onTap: _toggle,
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: Icon(
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
              _listening ? 'Listening… tap to stop' : 'Tap the mic and speak',
              style: Theme.of(context).textTheme.titleMedium,
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
            decoration: const InputDecoration(
              labelText: 'What was heard (you can edit this)',
              hintText: 'Aj 300 rupay petrol ka kharcha hua, 200 ki chai pi, 500 ki grocery ki…',
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
