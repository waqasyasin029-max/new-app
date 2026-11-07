import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/account_style.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../logic/expense_parser.dart';
import '../services/agent_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'confirm_expenses_screen.dart';
import 'settings_screen.dart';

class _Msg {
  _Msg(this.text, {this.mine = false, this.error = false});
  final String text;
  final bool mine;
  final bool error;
}

/// Type to the assistant: it writes expenses down (after you tap Save) and
/// answers questions like "how much did I spend today?". Quick entry is the
/// offline way when there is no Gemini key.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _quick = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  AgentService? _agent;
  bool _sending = false;
  bool _chat = true;
  String _keyUsed = '';

  static final _arabic = RegExp(r'[؀-ۿ]');

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _chat = s.geminiKey.trim().isNotEmpty;
    _startChat();
  }

  @override
  void dispose() {
    _input.dispose();
    _quick.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _startChat() {
    final s = context.read<AppState>();
    _msgs.clear();
    _keyUsed = s.geminiKey.trim();
    if (_keyUsed.isEmpty) {
      _agent = null;
      return;
    }
    final who = s.userName.trim().isEmpty ? '' : ' ${s.userName.trim()} sir';
    final hello =
        'Assalam o Alaikum$who! Likhein aaj kya kharcha hua, main likh leta hoon. '
        'Ya kuch poochna ho, jaise "is hafte kitna kharcha hua?".';
    _agent = AgentService(state: s, apiKey: _keyUsed, userName: s.userName)
      ..seedAssistant(hello);
    _msgs.add(_Msg(hello));
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// [text] goes to the assistant; [shown] is what the chat displays.
  Future<void> _send(String text, {String? shown}) async {
    final agent = _agent;
    final t = text.trim();
    if (agent == null || t.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg(shown ?? t, mine: true));
      _sending = true;
    });
    _toBottom();
    var askAccount = false;
    try {
      final turn = await agent
          .send(t)
          .timeout(
            const Duration(seconds: 75),
            onTimeout: () => throw const AgentError(
              'Gemini took too long (over 75 seconds). Try again.',
            ),
          );
      if (!mounted) return;
      setState(() => _msgs.add(_Msg(turn.text)));
      askAccount = agent.hasPending && !agent.pendingReady;
    } on AgentError catch (e) {
      if (mounted) setState(() => _msgs.add(_Msg(e.message, error: true)));
    } catch (e) {
      if (mounted) {
        setState(
          () => _msgs.add(_Msg('Something went wrong: $e', error: true)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _toBottom();
    }
    if (askAccount && mounted) await _pickAccount();
  }

  Future<void> _analyzeQuick() async {
    final text = _quick.text.trim();
    if (text.isEmpty) {
      snack(context, 'Type your expenses first.');
      return;
    }
    FocusScope.of(context).unfocus();
    final result = ExpenseParser.parse(text);
    final saved = await ConfirmExpensesScreen.show(
      context,
      rawText: text,
      result: result,
    );
    if (saved == true && mounted) _quick.clear();
  }

  /// Pop-up list of accounts; the choice goes to the assistant as a message.
  Future<void> _pickAccount() async {
    final accounts = context.read<AppState>().accounts;
    if (accounts.isEmpty || _sending) return;
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<Account>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Paid from',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            for (final a in accounts)
              ListTile(
                leading: Icon(AccountStyle.icon(a.type)),
                title: Text(a.name, verbatim: true),
                onTap: () => Navigator.pop(ctx, a),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      await _send('Ye ${picked.name} se paid hua', shown: picked.name);
    }
  }

  Widget _bubble(_Msg m) {
    final rtl = _arabic.hasMatch(m.text);
    final scheme = Theme.of(context).colorScheme;
    final bg = m.mine
        ? AppColors.primary
        : (m.error ? scheme.errorContainer : AppColors.surface);
    final fg = m.mine
        ? Colors.white
        : (m.error ? scheme.onErrorContainer : AppColors.ink);
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: bg,
          border: m.mine || m.error ? null : Border.all(color: AppColors.line),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(m.mine ? 18 : 4),
            bottomRight: Radius.circular(m.mine ? 4 : 18),
          ),
        ),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Text(
            m.text,
            verbatim: true,
            style: TextStyle(color: fg, fontSize: 15, height: rtl ? 1.8 : 1.4),
          ),
        ),
      ),
    );
  }

  Widget _pendingCard(AgentService agent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.primary, width: 1.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to save',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final l in agent.pendingLines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l,
                verbatim: true,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Total ${Fmt.money(agent.pendingTotal)}',
            verbatim: true,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (!agent.pendingReady)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                onPressed: _sending ? null : _pickAccount,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Choose where you paid from'),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _sending || !agent.pendingReady
                      ? null
                      : () => _send('ہاں، محفوظ کریں', shown: 'Save'),
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _sending
                      ? null
                      : () => _send('نہیں، رہنے دو', shown: 'Cancel'),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chatBody(AppState s) {
    final agent = _agent;
    if (agent == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 40, color: AppColors.muted),
              const SizedBox(height: 12),
              const Text(
                'Add your free Gemini key to chat with the assistant. Quick entry works without it.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                  if (mounted) setState(_startChat);
                },
                child: const Text('Open settings'),
              ),
            ],
          ),
        ),
      );
    }
    final fresh = _msgs.length == 1;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: [
              for (final m in _msgs) _bubble(m),
              if (_sending)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Thinking…',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              if (!_sending && agent.hasPending) _pendingCard(agent),
              if (fresh && !_sending)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in const [
                      'Aaj kitna kharcha hua?',
                      'Is hafte ka hisaab',
                      'Accounts mein kitna bacha hai?',
                    ])
                      ActionChip(
                        label: Text(q, verbatim: true),
                        onPressed: () => _send(q),
                      ),
                    ActionChip(
                      label: const Text(
                        'Add: 300 ka petrol cash se',
                        verbatim: true,
                      ),
                      onPressed: () {
                        _input.text = '300 ka petrol cash se';
                        _input.selection = TextSelection.collapsed(
                          offset: _input.text.length,
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (v) => _send(v),
                    decoration: InputDecoration(
                      hintText: tr('Type here, like: aaj 300 ka petrol'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : () => _send(_input.text),
                  icon: const Icon(Icons.send_rounded),
                  tooltip: tr('Send'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _quick,
          minLines: 5,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: tr('Your expenses'),
            hintText: tr(
              'Aj 300 rupay petrol ka kharcha hua, 200 ki chai pi, 500 ki grocery ki…',
            ),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _analyzeQuick,
          icon: const Icon(Icons.fact_check),
          label: const Text('Review expenses'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
        const SizedBox(height: 8),
        Text(
          'Works offline. Nothing is saved until you confirm it on the next screen.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    // The key was added or removed in Settings while this screen was open.
    if (s.geminiKey.trim() != _keyUsed && !_sending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_startChat);
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: [
          if (_chat && _agent != null)
            IconButton(
              tooltip: tr('New chat'),
              icon: const Icon(Icons.refresh),
              onPressed: _sending ? null : () => setState(_startChat),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text('Chat')),
                  ButtonSegment(value: false, label: Text('Quick entry')),
                ],
                selected: {_chat},
                onSelectionChanged: (v) => setState(() => _chat = v.first),
              ),
            ),
          ),
          Expanded(child: _chat ? _chatBody(s) : _quickBody()),
        ],
      ),
    );
  }
}
