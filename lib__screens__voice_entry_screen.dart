import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../logic/expense_parser.dart';
import '../logic/urdu_speech.dart';
import '../services/agent_service.dart';
import '../services/assistant_voice.dart';
import '../services/cloud_speech_service.dart';
import '../services/gemini_api.dart';
import '../services/speech_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'confirm_expenses_screen.dart';
import 'settings_screen.dart';

class VoiceEntryScreen extends StatefulWidget {
  const VoiceEntryScreen({super.key});

  @override
  State<VoiceEntryScreen> createState() => _VoiceEntryScreenState();
}

class _VoiceEntryScreenState extends State<VoiceEntryScreen>
    with SingleTickerProviderStateMixin {
  final SpeechService _speech = SpeechService();
  final CloudSpeechService _cloud = CloudSpeechService();
  final AssistantVoice _voice = AssistantVoice();
  bool _usingCloud = false;
  bool _busy = false;

  // Talking assistant state.
  bool _assistantActive = false;
  bool _speaking = false;
  bool _thinking = false;
  String _userLine = '';
  String _assistantLine = '';
  String _lastHeard = '';
  String _debug = '';
  int _session = 0;
  Completer<String?>? _turn;
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
      if (_assistantActive) {
        // In assistant mode the conversation decides what goes in the box.
        _lastHeard = t;
        if (_usingCloud) _complete(t);
        return;
      }
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
        if (_assistantActive && !_usingCloud) {
          // Phone engine finished one answer.
          Future.delayed(const Duration(milliseconds: 300), () {
            _complete(_lastHeard.trim().isEmpty ? null : _lastHeard);
          });
        }
      }
    }

    void onError(String m) {
      if (mounted) setState(() => _error = m);
      if (_assistantActive) _complete(null);
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
    _session++;
    _complete(null);
    _voice.dispose();
    _speech.dispose();
    _cloud.dispose();
    _pulse.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_assistantActive) {
      await _cancelAssistant();
      return;
    }
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
    if (app.assistantOn) {
      if (app.geminiKey.trim().isEmpty) {
        setState(
          () => _error = 'Add your Gemini key first: Settings > Voice input > Gemini assistant.',
        );
        return;
      }
      _voice.configure(
        geminiKey: app.geminiKey,
        geminiVoice: app.geminiVoice,
        geminiModel: app.geminiModel,
        lastGood: app.geminiTtsOk,
        upliftKey: app.upliftKey,
        upliftVoice: app.upliftVoice,
      );
      _voice.onNotice = (m) {
        if (mounted) setState(() => _error = m);
      };
      unawaited(_runAgent());
      return;
    }
    if (app.useCloudVoice) {
      _usingCloud = true;
      await _cloud.start(
        apiKey: app.sttKey,
        provider: app.sttProvider,
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
    await _speech.start(localeId: app.speechLocale, existing: _text.text);
  }

  // ---------------------------------------------------------------------
  // Talking assistant: Gemini decides what to say and uses tools to save
  // expenses (only after a spoken yes) or to answer questions.
  // ---------------------------------------------------------------------

  void _complete(String? value) {
    final t = _turn;
    if (t != null && !t.isCompleted) t.complete(value);
  }

  Future<void> _cancelAssistant() async {
    _session++;
    _complete(null);
    await _voice.stop();
    if (_listening) {
      await (_usingCloud ? _cloud.cancel() : _speech.cancel());
    }
    if (mounted) {
      setState(() {
        _assistantActive = false;
        _speaking = false;
        _thinking = false;
        _assistantLine = '';
        _userLine = '';
      });
    }
  }

  Future<void> _say(String text, {String? spoken}) async {
    if (!mounted) return;
    setState(() {
      _assistantLine = text;
      _speaking = _voice.ready;
    });
    await _voice.speak(spoken ?? text);
    if (mounted) setState(() => _speaking = false);
  }

  /// Listens for one answer. Returns null when nothing was understood.
  Future<String?> _listenTurn() async {
    final app = context.read<AppState>();
    setState(() => _error = null);
    _lastHeard = '';
    _turn = Completer<String?>();
    _usingCloud = app.useCloudVoice;
    if (_usingCloud) {
      await _cloud.start(
        apiKey: app.sttKey,
        provider: app.sttProvider,
        localeId: app.speechLocale,
        existing: '',
      );
    } else if (await _speech.init()) {
      await _speech.start(localeId: app.speechLocale, existing: '', once: true);
    } else {
      _complete(null);
    }
    final result = await _turn!.future.timeout(
      const Duration(seconds: 100),
      onTimeout: () => null,
    );
    _turn = null;
    return result;
  }

  Future<void> _closeAfterSave(int n, double total, String left) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _assistantActive = false;
      _speaking = false;
    });
    nav.pop();
    if (n > 0) {
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            'Saved $n expense${n == 1 ? '' : 's'} • ${Fmt.money(total)}\n$left',
          ),
        ),
      );
    }
  }

  Future<void> _runAgent() async {
    final my = ++_session;
    bool alive() => mounted && _session == my;
    final app = context.read<AppState>();
    final agent = AgentService(
      state: app,
      apiKey: app.geminiKey,
      userName: app.userName,
    );
    setState(() {
      _assistantActive = true;
      _error = null;
      _userLine = '';
      _text.clear();
    });

    final hello = UrduSpeech.greeting(app.userName, DateTime.now());
    agent.seedAssistant(hello);
    await _say(hello);

    var silent = 0;
    var failures = 0;
    while (alive()) {
      final heard = await _listenTurn();
      if (!alive()) return;
      final text = (heard ?? '').trim();
      if (text.isEmpty) {
        silent++;
        if (silent >= 2) {
          if (agent.savedCount > 0) {
            await _say('ٹھیک ہے، اللہ حافظ!');
            if (alive()) {
              await _closeAfterSave(
                agent.savedCount,
                agent.savedTotal,
                agent.lastLeft,
              );
            }
            return;
          }
          await _say('کچھ سنائی نہیں دیا۔ جب تیار ہوں، مائیک دوبارہ دبائیں۔');
          break;
        }
        await _say('جی، میں سن رہا ہوں۔ آپ بولیے۔');
        continue;
      }
      silent = 0;
      setState(() {
        _userLine = text;
        _thinking = true;
      });

      AgentTurn turn;
      final watch = Stopwatch()..start();
      try {
        turn = await agent
            .send(text)
            .timeout(
              const Duration(seconds: 75),
              onTimeout: () => throw const AgentError(
                'Gemini took too long (over 75 seconds). Try again.',
                network: true,
              ),
            );
        if (mounted) {
          setState(
            () => _debug =
                'Gemini answered in ${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s (${GeminiApi.lastModel})',
          );
        }
      } on AgentError catch (e) {
        if (!alive()) return;
        setState(() {
          _thinking = false;
          _error = e.message;
        });
        failures++;
        if (failures >= 2 || !e.network) {
          await _say(
            e.network
                ? 'معاف کیجیے، انٹرنیٹ کا مسئلہ ہے۔ تھوڑی دیر بعد دوبارہ کوشش کیجیے۔'
                : 'معاف کیجیے، اسسٹنٹ سے رابطہ نہیں ہو سکا۔',
          );
          break;
        }
        await _say('معاف کیجیے، انٹرنیٹ سست ہے۔ دوبارہ بولیے۔');
        continue;
      } catch (_) {
        if (!alive()) return;
        setState(() => _thinking = false);
        await _say('معاف کیجیے، کچھ گڑبڑ ہو گئی۔ دوبارہ بولیے۔');
        failures++;
        if (failures >= 3) break;
        continue;
      }
      if (!alive()) return;
      failures = 0;
      setState(() => _thinking = false);
      await _say(turn.text, spoken: UrduSpeech.spokenDigits(turn.text));
      if (!alive()) return;
      if (turn.ended) {
        await _closeAfterSave(
          agent.savedCount,
          agent.savedTotal,
          agent.lastLeft,
        );
        return;
      }
    }

    if (mounted && _session == my) {
      setState(() {
        _assistantActive = false;
        _speaking = false;
        _thinking = false;
      });
    }
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Talking assistant',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Talks with you, saves your expenses and answers questions like "how much today?"',
              style: TextStyle(fontSize: 12),
            ),
            value: state.assistantOn,
            onChanged: _listening || _assistantActive
                ? null
                : (v) => state.setAssistantOn(v),
          ),
          const SizedBox(height: 16),
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
                  onTap: _busy && !_assistantActive ? null : _toggle,
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: _busy || _thinking
                        ? const Padding(
                            padding: EdgeInsets.all(34),
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _listening || _assistantActive
                                ? Icons.stop
                                : Icons.mic,
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
              _thinking
                  ? 'Thinking…'
                  : _busy
                  ? 'Converting your voice to text…'
                  : _speaking
                  ? 'Assistant is speaking…'
                  : _listening
                  ? 'Listening… tap to stop'
                  : 'Tap the mic and speak',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_assistantActive && _userLine.isNotEmpty)
            AppCard(
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.mic_none_rounded, color: AppColors.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _userLine,
                        verbatim: true,
                        style: TextStyle(color: AppColors.muted, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_assistantActive && _debug.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _debug,
                verbatim: true,
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          if (_assistantActive && _assistantLine.isNotEmpty)
            AppCard(
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.record_voice_over_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          _assistantLine,
                          verbatim: true,
                          style: const TextStyle(fontSize: 16, height: 1.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (state.voiceEngine == 'cloud' &&
              state.groqKey.trim().isEmpty &&
              state.geminiKey.trim().isEmpty)
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
