import '../core/format.dart';
import '../core/i18n.dart' show tr;
import '../core/ur_strings.dart' show urExact;
import '../data/models.dart';
import '../logic/account_matcher.dart';
import '../logic/urdu_speech.dart';
import '../state/app_state.dart';
import 'gemini_api.dart';

class AgentError implements Exception {
  final String message;
  final bool network;
  const AgentError(this.message, {this.network = false});
  @override
  String toString() => message;
}

class AgentTurn {
  final String text;
  final bool ended;
  const AgentTurn(this.text, this.ended);
}

class _Item {
  final String description;
  final double amount;
  final Category category;
  final Account? account;
  const _Item(this.description, this.amount, this.category, this.account);
}

/// A talking assistant powered by Gemini (the user's own free key). The model decides what to say; it can only touch the
/// user's data through the tools below, and it can only save after the user
/// has said yes (checked here in code, not just in the prompt).
class AgentService {
  final AppState state;
  final String apiKey;
  final String userName;

  final List<Map<String, dynamic>> _msgs = [];
  String _greeting = '';
  List<_Item>? _pending;
  DateTime _pendingDate = Fmt.dateOnly(DateTime.now());
  String _pendingRaw = '';
  String _lastUser = '';
  bool _ended = false;

  int savedCount = 0;
  double savedTotal = 0;
  String lastLeft = '';

  AgentService({
    required this.state,
    required this.apiKey,
    required this.userName,
  });

  /// What the assistant already said (the greeting); it goes into the prompt.
  void seedAssistant(String text) => _greeting = text;

  /// Keeps the history short without cutting a tool call from its answer.
  void _trim() {
    if (_msgs.length <= 40) return;
    var cut = _msgs.length - 40;
    bool startsTurn(int i) {
      final m = _msgs[i];
      if (m['role'] != 'user') return false;
      final parts = (m['parts'] as List?) ?? const [];
      return parts.isNotEmpty &&
          parts.first is Map &&
          (parts.first as Map).containsKey('text');
    }

    while (cut < _msgs.length && !startsTurn(cut)) {
      cut++;
    }
    if (cut < _msgs.length) _msgs.removeRange(0, cut);
  }

  Future<AgentTurn> send(String userText) async {
    _lastUser = userText;
    _ended = false;
    _msgs.add({
      'role': 'user',
      'parts': [
        {'text': userText},
      ],
    });
    _trim();

    for (var i = 0; i < 6; i++) {
      final content = await _chat();
      final parts = ((content['parts'] as List?) ?? const [])
          .whereType<Map>()
          .toList();
      final text = parts
          .where((p) => p['text'] is String && p['thought'] != true)
          .map((p) => (p['text'] as String).trim())
          .where((t) => t.isNotEmpty)
          .join(' ')
          .trim();
      final calls = parts.where((p) => p['functionCall'] is Map).toList();
      // Keep the model's own answer exactly as it came (Gemini needs its
      // hidden signatures sent back with the tool results).
      _msgs.add({'role': 'model', 'parts': parts});
      if (calls.isEmpty) {
        return AgentTurn(text.isEmpty ? 'جی؟' : text, _ended);
      }
      final answers = <Map<String, dynamic>>[];
      for (final c in calls) {
        final fn = (c['functionCall'] as Map).cast<String, dynamic>();
        final name = (fn['name'] ?? '').toString();
        Object result;
        try {
          final args = fn['args'] is Map
              ? (fn['args'] as Map).cast<String, dynamic>()
              : <String, dynamic>{};
          result = await _runTool(name, args);
        } catch (e) {
          result = {'error': '$e'};
        }
        answers.add({
          'functionResponse': {
            'name': name,
            'response': {'result': result},
          },
        });
      }
      _msgs.add({'role': 'user', 'parts': answers});
      if (_ended && text.isNotEmpty) return AgentTurn(text, true);
    }
    return AgentTurn('معاف کیجیے، دوبارہ بتائیے۔', _ended);
  }

  // ---------------------------------------------------------------- model

  Future<Map<String, dynamic>> _chat() async {
    Map<String, dynamic> j;
    try {
      j = await GeminiApi.generate(
        key: apiKey,
        body: {
          'systemInstruction': {
            'parts': [
              {'text': _system()},
            ],
          },
          'contents': _msgs,
          'tools': [
            {'functionDeclarations': _tools},
          ],
          'toolConfig': {
            'functionCallingConfig': {'mode': 'AUTO'},
          },
          'generationConfig': {'temperature': 0.3},
        },
      );
    } on GeminiError catch (e) {
      throw AgentError(e.message, network: e.network);
    }
    final cands = j['candidates'];
    if (cands is List && cands.isNotEmpty && cands.first is Map) {
      final c = (cands.first as Map)['content'];
      if (c is Map) return c.cast<String, dynamic>();
      return <String, dynamic>{'parts': []};
    }
    throw const AgentError('Gemini gave no answer. Please try again.');
  }

  String _system() {
    final now = DateTime.now();
    final cats = state.categories.map((c) => c.name).join(', ');
    final accs = state.accounts.map((a) => a.name).join(', ');
    final who = userName.trim().isEmpty ? 'the user' : userName.trim();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final hm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return '''
You are "Kharcha Assistant", a warm, polite voice assistant inside a personal expense tracker used by $who in Pakistan. You are talking out loud, like a friendly waiter who takes an order and repeats it back before confirming.

LANGUAGE AND STYLE
- Always reply in Urdu script. No Roman Urdu. Account and category names are written in Urdu script too (جاز کیش، نقد، کھانا).
- Keep every reply short: one or two spoken sentences. Polite "آپ". Natural, friendly, never robotic.
- Write amounts as digits (for example 300). Never write "Rs", currency symbols or lists. The app reads the digits aloud.
- The user speaks Roman Urdu, Urdu or English. Speech recognition can contain mistakes: use common sense, but ask if an amount is unclear.
- Use the name "$who سر" only now and then, not in every reply.
- No markdown, no emojis.

TOOLS
- add_expenses: record what the user spent (this only PREPARES the order, nothing is saved yet).
- confirm_save: save the prepared order.
- cancel_pending: throw the prepared order away.
- get_spending: totals for a period, optionally for one category or account.
- get_balances: current balance of every account.
- end_conversation: close the conversation.

RULES FOR MONEY DATA (very important)
- Never invent amounts, balances or totals. Use tool results only.
- When the user tells expenses, call add_expenses with the COMPLETE list. If an item has no account, ask "یہ کہاں سے ادا کیا؟" and name the accounts, then call add_expenses again with the full list including accounts.
- After add_expenses succeeds, repeat the order in one short sentence (items, amounts, total, account) and ask if it is correct. Do NOT save yet.
- Call confirm_save ONLY after the user clearly says yes to that repeat (for example ہاں، ٹھیک ہے، کر دو). If they correct something, call add_expenses again with the corrected full list and repeat again. If they say no, call cancel_pending and ask what to change.
- After confirm_save, say it is saved, give the remaining balance of the account(s) from the tool result, and ask if there is anything else.
- For questions about spending or balances, call get_spending or get_balances and answer briefly with the real numbers.
- When the user is finished (thanks, nothing more, خدا حافظ), say a short goodbye and call end_conversation.
- If asked something unrelated, answer in a sentence and steer back to expenses.

CONTEXT
- You already greeted the user at the start with: "$_greeting". Do not greet again.
- Now: $date $hm (Pakistan time). Weeks start on Monday.
- Categories (use exactly these names in tool calls): $cats
- Accounts (use exactly these names in tool calls): $accs
''';
  }

  static final List<Map<String, dynamic>> _tools = [
    {
      'name': 'add_expenses',
      'description': 'Prepare the complete list of expenses the user just told. Replaces any earlier prepared list. Nothing is saved until confirm_save.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'items': {
            'type': 'ARRAY',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'description': {
                  'type': 'STRING',
                  'description': 'Short name of what was bought, e.g. چائے',
                },
                'amount': {'type': 'NUMBER'},
                'category': {'type': 'STRING'},
                'account': {
                  'type': 'STRING',
                  'description': 'Account it was paid from. Leave out if the user did not say.',
                },
              },
              'required': ['description', 'amount', 'category'],
            },
          },
          'date': {
            'type': 'STRING',
            'description':
                'YYYY-MM-DD. Leave out for today. Never in the future.',
          },
        },
        'required': ['items'],
      },
    },
    {
      'name': 'confirm_save',
      'description': 'Save the prepared order. Only after the user clearly said yes to your repeat of it.',
    },
    {
      'name': 'cancel_pending',
      'description': 'Discard the prepared order without saving.',
    },
    {
      'name': 'get_spending',
      'description': 'How much was spent in a period, with top categories, biggest and latest expenses.',
      'parameters': {
        'type': 'OBJECT',
        'properties': {
          'period': {
            'type': 'STRING',
            'enum': [
              'today',
              'yesterday',
              'this_week',
              'last_week',
              'last_7_days',
              'last_30_days',
              'this_month',
              'last_month',
              'custom',
            ],
          },
          'from': {'type': 'STRING', 'description': 'YYYY-MM-DD, custom only'},
          'to': {'type': 'STRING', 'description': 'YYYY-MM-DD, custom only'},
          'category': {'type': 'STRING'},
          'account': {'type': 'STRING'},
        },
        'required': ['period'],
      },
    },
    {
      'name': 'get_balances',
      'description': 'Current balance of every account.',
    },
    {
      'name': 'end_conversation',
      'description': 'Close the conversation after the goodbye.',
    },
  ];

  // ---------------------------------------------------------------- tools

  Future<Object> _runTool(String name, Map<String, dynamic> a) async {
    switch (name) {
      case 'add_expenses':
        return _addExpenses(a);
      case 'confirm_save':
        return _confirmSave();
      case 'cancel_pending':
        _pending = null;
        return {'status': 'cancelled'};
      case 'get_spending':
        return _getSpending(a);
      case 'get_balances':
        return _getBalances();
      case 'end_conversation':
        _ended = true;
        return {'status': 'ok'};
    }
    return {'error': 'unknown tool $name'};
  }

  String _ur(String s) => urExact[s] ?? s;

  Category _category(String? name) {
    final cats = state.categories;
    final n = (name ?? '').trim().toLowerCase();
    for (final c in cats) {
      if (c.name.toLowerCase() == n || _ur(c.name) == name?.trim()) return c;
    }
    for (final c in cats) {
      if (n.isNotEmpty && c.name.toLowerCase().contains(n)) return c;
    }
    return state.categoryByName('Other');
  }

  Account? _account(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return null;
    for (final a in state.accounts) {
      if (a.name.toLowerCase() == n.toLowerCase() || _ur(a.name) == n) return a;
    }
    final id = AccountMatcher.match(n, [
      for (final a in state.accounts) (id: a.id, name: a.name),
    ]);
    if (id == null) return null;
    return state.accounts.firstWhere((a) => a.id == id);
  }

  Map<String, dynamic> _addExpenses(Map<String, dynamic> a) {
    final raw = (a['items'] as List?) ?? const [];
    final items = <_Item>[];
    for (final r in raw) {
      final m = (r as Map).cast<String, dynamic>();
      final amount = (m['amount'] as num?)?.toDouble() ?? 0;
      if (amount <= 0) {
        return {
          'error': 'Every item needs an amount above zero. Ask the user.',
        };
      }
      items.add(
        _Item(
          (m['description'] ?? '').toString().trim(),
          amount,
          _category(m['category']?.toString()),
          _account(m['account']?.toString()),
        ),
      );
    }
    if (items.isEmpty) return {'error': 'No expenses given.'};
    var date = Fmt.dateOnly(DateTime.now());
    final d = DateTime.tryParse((a['date'] ?? '').toString());
    if (d != null && !Fmt.dateOnly(d).isAfter(date)) date = Fmt.dateOnly(d);
    _pending = items;
    _pendingDate = date;
    _pendingRaw = _lastUser;
    final missing = [
      for (var i = 0; i < items.length; i++)
        if (items[i].account == null) items[i].description,
    ];
    return {
      'status': 'prepared_not_saved',
      'date': Fmt.key(date),
      'items': [
        for (final it in items)
          {
            'description': it.description,
            'amount': it.amount,
            'category': it.category.name,
            'account': it.account?.name,
            'account_urdu': it.account == null ? null : _ur(it.account!.name),
          },
      ],
      'total': items.fold<double>(0, (s, e) => s + e.amount),
      'missing_account_for': missing,
      'next': missing.isEmpty
          ? 'Repeat the order in one short sentence and ask if it is correct. Do not save yet.'
          : 'Ask which account it was paid from, then call add_expenses again with the full list.',
    };
  }

  Future<Map<String, dynamic>> _confirmSave() async {
    final items = _pending;
    if (items == null || items.isEmpty) {
      return {'error': 'Nothing is prepared. Call add_expenses first.'};
    }
    if (items.any((e) => e.account == null)) {
      return {'error': 'An account is missing. Ask the user which account.'};
    }
    if (!UrduSpeech.saysYes(_lastUser) || UrduSpeech.saysNo(_lastUser)) {
      return {
        'error': 'The user has not clearly said yes. Repeat the order and ask them to confirm.',
      };
    }
    final list = [
      for (final it in items)
        Expense(
          amount: it.amount,
          categoryId: it.category.id,
          accountId: it.account!.id,
          description: it.description.isEmpty
              ? it.category.name
              : it.description,
          date: _pendingDate,
          source: 'voice',
          rawText: _pendingRaw,
        ),
    ];
    await state.expenses.insertMany(list);
    state.changed();
    _pending = null;
    final used = {for (final e in list) e.accountId!};
    final bals = await state.accountRepo.balances();
    final left = <String>[];
    final out = <Map<String, Object>>[];
    for (final b in bals) {
      if (!used.contains(b.account.id)) continue;
      left.add(tr('${b.account.name} left ${Fmt.money(b.balance)}'));
      out.add({
        'account': b.account.name,
        'account_urdu': _ur(b.account.name),
        'balance': b.balance,
      });
    }
    savedCount += list.length;
    savedTotal += list.fold<double>(0, (s, e) => s + e.amount);
    lastLeft = left.join(' • ');
    return {'status': 'saved', 'count': list.length, 'balances_now': out};
  }

  Future<Map<String, dynamic>> _getBalances() async {
    final bals = await state.accountRepo.balances();
    return {
      'balances': [
        for (final b in bals)
          {
            'account': b.account.name,
            'account_urdu': _ur(b.account.name),
            'balance': b.balance,
          },
      ],
    };
  }

  (DateTime, DateTime) _range(Map<String, dynamic> a) {
    final now = Fmt.dateOnly(DateTime.now());
    DateTime day(int back) => DateTime(now.year, now.month, now.day - back);
    final monday = day(now.weekday - 1);
    switch ((a['period'] ?? 'this_month').toString()) {
      case 'today':
        return (now, now);
      case 'yesterday':
        return (day(1), day(1));
      case 'this_week':
        return (monday, now);
      case 'last_week':
        return (
          DateTime(monday.year, monday.month, monday.day - 7),
          DateTime(monday.year, monday.month, monday.day - 1),
        );
      case 'last_7_days':
        return (day(6), now);
      case 'last_30_days':
        return (day(29), now);
      case 'last_month':
        return (
          DateTime(now.year, now.month - 1, 1),
          DateTime(now.year, now.month, 0),
        );
      case 'custom':
        final f = DateTime.tryParse((a['from'] ?? '').toString());
        final t = DateTime.tryParse((a['to'] ?? '').toString());
        if (f != null) {
          return (Fmt.dateOnly(f), t == null ? now : Fmt.dateOnly(t));
        }
        return (Fmt.firstOfMonth(now), now);
      default:
        return (Fmt.firstOfMonth(now), now);
    }
  }

  Future<Map<String, dynamic>> _getSpending(Map<String, dynamic> a) async {
    final (from, to) = _range(a);
    final catName = a['category']?.toString();
    final catId = (catName == null || catName.trim().isEmpty)
        ? null
        : _category(catName).id;
    final acc = _account(a['account']?.toString());
    var rows = await state.expenses.list(from: from, to: to, categoryId: catId);
    if (acc != null) rows = rows.where((e) => e.accountId == acc.id).toList();
    final total = rows.fold<double>(0, (s, e) => s + e.amount);
    final byCat = <String, double>{};
    for (final e in rows) {
      final n = e.categoryName ?? 'Other';
      byCat[n] = (byCat[n] ?? 0) + e.amount;
    }
    final top = byCat.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));
    Map<String, Object?> row(Expense e) => {
      'date': Fmt.key(e.date),
      'description': e.description,
      'amount': e.amount,
      'category': e.categoryName,
      'account': e.accountName,
    };
    final biggest = [...rows]..sort((x, y) => y.amount.compareTo(x.amount));
    return {
      'from': Fmt.key(from),
      'to': Fmt.key(to),
      'category_filter': catId == null ? null : _category(catName).name,
      'account_filter': acc?.name,
      'total': total,
      'count': rows.length,
      'top_categories': [
        for (final e in top.take(5))
          {'category': e.key, 'category_urdu': _ur(e.key), 'total': e.value},
      ],
      'biggest': biggest.take(3).map(row).toList(),
      'latest': rows.take(5).map(row).toList(),
    };
  }
}
