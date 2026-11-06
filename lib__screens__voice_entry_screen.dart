import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../core/theme.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/ur_strings.dart' show urExact;
import '../data/models.dart';
import '../logic/account_matcher.dart';
import '../logic/expense_parser.dart';
import '../logic/urdu_speech.dart';
import '../services/agent_service.dart';
import '../services/cloud_speech_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
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
  final TtsService _tts = TtsService();
  bool _usingCloud = false;
  bool _busy = false;

  // Talking assistant state.
  bool _assistantActive = false;
  bool _speaking = false;
  bool _thinking = false;
  String _userLine = '';
  int _session = 0;
  String _assistantLine = '';
  String _lastHeard = '';
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
    _tts.stop();
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
      _tts.configure(
        key: app.elevenKey,
        voiceId: app.elevenVoiceId,
        model: app.elevenModel,
        enabled: app.naturalVoice,
      );
      _tts.onNotice = (m) {
        if (mounted) setState(() => _error = m);
      };
      if (await _tts.init()) {
        if (app.smartAgent && app.groqKey.trim().isNotEmpty) {
          unawaited(_runAgent());
        } else {
          unawaited(_runAssistant());
        }
        return;
      }
      setState(
        () => _error = 'Urdu text-to-speech is not installed on this phone. Install "Speech Services by Google" and its Urdu voice, then try again. Normal voice entry is used for now.',
      );
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

  // ---------------------------------------------------------------------
  // Talking assistant: greets, listens, repeats the order, asks to confirm.
  // ---------------------------------------------------------------------

  void _complete(String? value) {
    final t = _turn;
    if (t != null && !t.isCompleted) t.complete(value);
  }

  Future<void> _cancelAssistant() async {
    _session++;
    _complete(null);
    await _tts.stop();
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
      _speaking = true;
    });
    await _tts.speak(spoken ?? text);
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
        apiKey: app.groqKey,
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

  static String _join(String a, String b) =>
      [a, b].where((x) => x.trim().isNotEmpty).join(' ').trim();

  String _urdu(String s) => urExact[s] ?? s;

  List<({int id, String name})> get _accs => [
    for (final a in context.read<AppState>().accounts) (id: a.id, name: a.name),
  ];

  String _accountName(int id) {
    for (final a in context.read<AppState>().accounts) {
      if (a.id == id) return _urdu(a.name);
    }
    return '';
  }

  /// Which account each item was paid from: named in the sentence, or the one
  /// the assistant asked about.
  List<int?> _resolveAccounts(ParseResult r, String raw, int? chosen) {
    final accs = _accs;
    final per = [
      for (final p in r.items) AccountMatcher.match(p.sourceText, accs),
    ];
    final whole = per.every((x) => x == null)
        ? AccountMatcher.match(raw, accs)
        : null;
    return [for (final x in per) x ?? whole ?? chosen];
  }

  String _accountQuestion() {
    final names = [
      for (final a in context.read<AppState>().accounts) _urdu(a.name),
    ];
    final list = names.length < 2
        ? names.join()
        : '${names.sublist(0, names.length - 1).join('، ')} یا ${names.last}';
    return 'یہ رقم کہاں سے ادا کی؟ $list؟';
  }

  /// Saves the confirmed order straight away (the spoken "yes" was the confirmation).
  Future<({int n, double total, String left, String speech})?> _saveByVoice(
    String raw,
    ParseResult r,
    List<int?> accIds,
  ) async {
    final state = context.read<AppState>();
    final accs = _accs;
    final list = <Expense>[];
    for (var i = 0; i < r.items.length; i++) {
      final p = r.items[i];
      var desc = p.description;
      final stripped = AccountMatcher.strip(desc, accs);
      if (stripped.isNotEmpty) {
        desc = stripped[0].toUpperCase() + stripped.substring(1);
      }
      final cat = state.categoryByName(p.category);
      if (desc.trim().isEmpty) desc = cat.name;
      list.add(
        Expense(
          amount: p.amount!,
          categoryId: cat.id,
          accountId: accIds[i]!,
          description: desc,
          date: Fmt.dateOnly(DateTime.now()),
          source: 'voice',
          rawText: raw,
        ),
      );
    }
    try {
      await state.expenses.insertMany(list);
      state.changed();
      final used = {for (final e in list) e.accountId!};
      final bals = await state.accountRepo.balances();
      final left = <String>[];
      final speech = <String>[];
      for (final b in bals) {
        if (!used.contains(b.account.id)) continue;
        left.add(tr('${b.account.name} left ${Fmt.money(b.balance)}'));
        final amount = UrduSpeech.money(b.balance.abs());
        speech.add(
          '${_urdu(b.account.name)} میں اب ${b.balance < 0 ? 'منفی ' : ''}$amount باقی ہیں',
        );
      }
      return (
        n: list.length,
        total: list.fold<double>(0, (a, e) => a + e.amount),
        left: left.join(' • '),
        speech: speech.join('، '),
      );
    } catch (_) {
      return null;
    }
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

  /// Natural conversation: a language model decides what to say and asks the
  /// app to do things through tools (see AgentService).
  Future<void> _runAgent() async {
    final my = ++_session;
    bool alive() => mounted && _session == my;
    final app = context.read<AppState>();
    final agent = AgentService(
      state: app,
      apiKey: app.groqKey,
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
      try {
        turn = await agent.send(text);
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
                : 'معاف کیجیے، اے آئی سے رابطہ نہیں ہو سکا۔ سیٹنگز میں کی دیکھ لیجیے۔',
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

  Future<void> _runAssistant() async {
    final my = ++_session;
    bool alive() => mounted && _session == my;
    final app = context.read<AppState>();
    setState(() {
      _assistantActive = true;
      _error = null;
      _text.clear();
    });

    await _say(UrduSpeech.greeting(app.userName, DateTime.now()));

    // Stages: 0 = waiting for the order, 1 = asking which account,
    // 2 = waiting for yes/no on the repeated order, 3 = "anything else?".
    var stage = 0;
    var collected = '';
    int? chosenAcc;
    var silent = 0;
    var unclear = 0;
    var savedCount = 0;
    var savedTotal = 0.0;
    var lastLeft = '';
    ParseResult result = const ParseResult([], []);
    var accIds = <int?>[];

    Future<void> repeatOrAsk() async {
      result = ExpenseParser.parse(collected);
      accIds = _resolveAccounts(result, collected, chosenAcc);
      unclear = 0;
      if (accIds.any((x) => x == null)) {
        stage = 1;
        await _say(_accountQuestion());
      } else {
        stage = 2;
        final names = [for (final id in accIds) _accountName(id!)];
        await _say(
          '${UrduSpeech.repeatOrder(result, _urdu, accountNames: names)} کیا یہ ٹھیک ہے؟',
        );
      }
    }

    while (alive()) {
      final heard = await _listenTurn();
      if (!alive()) return;
      final text = (heard ?? '').trim();

      if (text.isEmpty) {
        silent++;
        if (silent >= 2) {
          if (savedCount > 0) {
            await _say('ٹھیک ہے، اللہ حافظ!');
            if (alive())
              await _closeAfterSave(savedCount, savedTotal, lastLeft);
            return;
          }
          await _say('کچھ سنائی نہیں دیا۔ جب تیار ہوں، مائیک دوبارہ دبائیں۔');
          break;
        }
        await _say('معاف کیجیے، آواز صاف نہیں آئی۔ دوبارہ بتائیے۔');
        continue;
      }
      silent = 0;

      if (stage == 3) {
        final reply = UrduSpeech.classify(text);
        if (reply == Reply.no) {
          await _say('ٹھیک ہے، اللہ حافظ!');
          if (alive()) await _closeAfterSave(savedCount, savedTotal, lastLeft);
          return;
        }
        if (reply == Reply.yes) {
          stage = 0;
          collected = '';
          chosenAcc = null;
          setState(() => _text.clear());
          await _say('جی، بتائیے۔');
          continue;
        }
        if (ExpenseParser.parse(text).items.isEmpty) {
          unclear++;
          if (unclear >= 2) {
            await _say('ٹھیک ہے، اللہ حافظ!');
            if (alive()) {
              await _closeAfterSave(savedCount, savedTotal, lastLeft);
            }
            return;
          }
          await _say('براہِ کرم ہاں یا نہیں کہیے۔');
          continue;
        }
        // A new order was spoken straight away.
        stage = 0;
        collected = '';
        chosenAcc = null;
      } else if (stage == 2) {
        final reply = UrduSpeech.classify(text);
        if (reply == Reply.yes) {
          final saved = await _saveByVoice(collected, result, accIds);
          if (!alive()) return;
          if (saved == null) {
            await _say('معاف کیجیے، محفوظ نہیں ہو سکا۔ اسکرین پر دیکھ لیجیے۔');
            if (alive()) await _finishAssistant(collected);
            return;
          }
          savedCount += saved.n;
          savedTotal += saved.total;
          lastLeft = saved.left;
          setState(() => _text.clear());
          collected = '';
          chosenAcc = null;
          stage = 3;
          unclear = 0;
          await _say(
            'محفوظ ہو گیا۔ ${saved.speech}۔ کیا کچھ اور خرچہ بھی لکھنا ہے؟',
          );
          continue;
        }
        if (reply == Reply.no) {
          collected = '';
          chosenAcc = null;
          stage = 0;
          setState(() => _text.clear());
          await _say('کوئی بات نہیں، دوبارہ بتائیے۔');
          continue;
        }
        if (ExpenseParser.parse(text).items.isEmpty) {
          unclear++;
          if (unclear >= 2) {
            await _say('ٹھیک ہے، اسکرین پر خود دیکھ لیجیے۔');
            if (alive()) await _finishAssistant(collected);
            return;
          }
          await _say('براہِ کرم ہاں یا نہیں کہیے۔');
          continue;
        }
        // More items added to the same order: handled below.
        stage = 0;
      } else if (stage == 1) {
        final id = AccountMatcher.match(text, _accs);
        if (id == null) {
          unclear++;
          if (unclear >= 2) {
            await _say('ٹھیک ہے، اسکرین پر خود چن لیجیے۔');
            if (alive()) await _finishAssistant(collected);
            return;
          }
          await _say('معاف کیجیے، اکاؤنٹ سمجھ نہیں آیا۔ دوبارہ بتائیے۔');
          continue;
        }
        chosenAcc = id;
        await repeatOrAsk();
        continue;
      }

      // The order (or more items added to it).
      collected = _join(collected, text);
      final parsed = ExpenseParser.parse(collected);
      setState(() {
        _text.text = collected;
        _text.selection = TextSelection.collapsed(offset: collected.length);
      });
      if (parsed.items.isEmpty) {
        collected = '';
        stage = 0;
        await _say(
          'مجھے کوئی خرچہ سمجھ نہیں آیا۔ مثال کے طور پر کہیے، تین سو کا پیٹرول۔',
        );
        continue;
      }
      if (parsed.missingAmounts > 0) {
        collected = '';
        stage = 0;
        await _say('کسی خرچے کی رقم سنائی نہیں دی۔ پوری بات دوبارہ بتائیے۔');
        continue;
      }
      await repeatOrAsk();
    }

    if (mounted && _session == my) {
      setState(() {
        _assistantActive = false;
        _speaking = false;
      });
    }
  }

  Future<void> _finishAssistant(String collected) async {
    if (!mounted) return;
    setState(() {
      _assistantActive = false;
      _speaking = false;
      _text.text = collected;
    });
    await _analyze();
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
              'Greets you, listens, repeats your order and asks you to confirm',
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
