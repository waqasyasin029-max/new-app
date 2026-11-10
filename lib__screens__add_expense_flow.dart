import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../services/sound_service.dart';
import '../core/account_style.dart';
import '../core/category_style.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../logic/lexicon.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../core/app_icons.dart';

class _Saved {
  final int id;
  final double amount;
  final String category;
  final String account;
  final double left;
  const _Saved(this.id, this.amount, this.category, this.account, this.left);
}

/// The plus button: amount, then category, then "Paid from" in one pop-up
/// sheet. Choosing the account saves the expense; the message that follows
/// has an Undo.
class AddExpenseFlow {
  static Future<void> start(BuildContext context) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showModalBottomSheet<_Saved>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _FlowSheet(),
    );
    if (saved == null) return;
    SoundService.saved();
    showOk(
      messenger,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saved ${Fmt.money(saved.amount)} · ${saved.category}'),
          Text(
            '${saved.account} left ${Fmt.money(saved.left)}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      action: SnackBarAction(
        label: tr('Undo'),
        onPressed: () async {
          await state.expenses.delete(saved.id);
          state.changed();
        },
      ),
    );
  }
}

class _FlowSheet extends StatefulWidget {
  const _FlowSheet();

  @override
  State<_FlowSheet> createState() => _FlowSheetState();
}

class _FlowSheetState extends State<_FlowSheet> {
  int _step = 0; // 0 amount, 1 title, 2 category, 3 paid from
  String _digits = '';
  Category? _cat;
  final _title = TextEditingController();
  String _detectedFor = '';
  List<TitleSuggestion> _sugs = [];
  List<AccountBalance> _bals = [];
  bool _saving = false;

  /// 0 = today, 1 = yesterday, and so on. Chosen with the arrows on step 1.
  int _daysBack = 0;

  DateTime get _date {
    final t = Fmt.dateOnly(DateTime.now());
    return DateTime(t.year, t.month, t.day - _daysBack);
  }

  double get _amount => double.tryParse(_digits) ?? 0;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  /// The category that matches the typed title ("biryani" is Food), if any.
  Category? _detect(AppState s) {
    final name = Lexicon.categorizeText(_title.text);
    if (name == null) return null;
    for (final c in s.categories) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// The category this exact title was filed under before, if it was used often.
  Category? _fromHistory(AppState s) {
    final key = _title.text.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final g in _sugs) {
      if (g.title.toLowerCase() == key) {
        for (final c in s.categories) {
          if (c.id == g.categoryId) return c;
        }
      }
    }
    return null;
  }

  /// From the title step: pre-select the matching category, then continue.
  void _titleNext(AppState s) {
    final text = _title.text.trim();
    if (text != _detectedFor) {
      _detectedFor = text;
      final d = _fromHistory(s) ?? _detect(s);
      if (d != null) _cat = d;
    }
    setState(() => _step = 2);
  }

  /// Titles typed before (2+ times) that fit what is typed now.
  List<TitleSuggestion> _matching() {
    final q = _title.text.trim().toLowerCase();
    final out = <TitleSuggestion>[];
    for (final g in _sugs) {
      final t = g.title.toLowerCase();
      if (t == q) continue;
      if (q.isEmpty || t.contains(q)) out.add(g);
      if (out.length >= 6) break;
    }
    return out;
  }

  void _useSuggestion(TitleSuggestion g) {
    _title.text = g.title;
    _title.selection = TextSelection.collapsed(offset: g.title.length);
    setState(() {});
  }

  String get _description {
    final t = _title.text.trim();
    if (t.isEmpty) return _cat?.name ?? '';
    return t[0].toUpperCase() + t.substring(1);
  }

  @override
  void initState() {
    super.initState();
    _loadBalances();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final g = await context.read<AppState>().expenses.frequentTitles();
    if (mounted) setState(() => _sugs = g);
  }

  Future<void> _loadBalances() async {
    final b = await context.read<AppState>().accountRepo.balances();
    if (mounted) setState(() => _bals = b);
  }

  void _key(String k) {
    setState(() {
      if (k == '<') {
        if (_digits.isNotEmpty)
          _digits = _digits.substring(0, _digits.length - 1);
        return;
      }
      if (k == '.') {
        if (_digits.contains('.') || _digits.length >= 9) return;
        _digits = _digits.isEmpty ? '0.' : '$_digits.';
        return;
      }
      final dot = _digits.indexOf('.');
      if (dot >= 0 && _digits.length - dot > 2) return; // two decimals
      if (_digits.length >= 9) return;
      _digits = _digits == '0' ? k : '$_digits$k';
    });
  }

  String get _shown {
    if (_digits.isEmpty) return '0';
    final dot = _digits.indexOf('.');
    final whole = dot < 0 ? _digits : _digits.substring(0, dot);
    final rest = dot < 0 ? '' : _digits.substring(dot);
    return '${Fmt.number(int.tryParse(whole) ?? 0)}$rest';
  }

  Future<void> _save(Account acc) async {
    final cat = _cat;
    if (cat == null || _saving || _amount <= 0) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final nav = Navigator.of(context);
    try {
      final id = await state.expenses.insert(
        Expense(
          amount: _amount,
          categoryId: cat.id,
          accountId: acc.id,
          description: _description,
          date: Fmt.dateOnly(_date),
        ),
      );
      state.changed();
      final left = await state.accountRepo.balanceOf(acc.id);
      nav.pop(_Saved(id, _amount, cat.name, acc.name, left));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      snack(context, 'Could not save: $e');
    }
  }

  Widget _handle() => Center(
    child: Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(top: 10, bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );

  Widget _header(String title, {String? chip, VoidCallback? onChip}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            if (chip != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onChip,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.fieldFill,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            chip,
                            verbatim: true,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(AppIcons.edit, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      IconButton(
        tooltip: tr('Close'),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.fieldFill,
          minimumSize: const Size(44, 44),
        ),
        icon: const Icon(AppIcons.close, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );

  Widget _keyButton(String k) {
    final back = k == '<';
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Semantics(
          button: true,
          label: back ? tr('Delete') : k,
          excludeSemantics: true,
          child: Material(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _key(k),
              onLongPress: back ? () => setState(() => _digits = '') : null,
              child: SizedBox(
                height: 54,
                child: Center(
                  child: back
                      ? const Icon(AppIcons.backspace, size: 24)
                      : Text(
                          k,
                          verbatim: true,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayArrow(IconData icon, VoidCallback? onTap) => Material(
    color: onTap == null ? AppColors.fieldFill.withOpacity(0.5) : AppColors.fieldFill,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.line : AppColors.ink,
        ),
      ),
    ),
  );

  /// "< Yesterday >": goes back one day per tap; the right arrow stops at today.
  Widget _dayStepper() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dayArrow(
          AppIcons.chevronLeft,
          () => setState(() => _daysBack += 1),
        ),
        const SizedBox(width: 12),
        Container(
          constraints: const BoxConstraints(minWidth: 140),
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _daysBack == 0
                ? AppColors.fieldFill
                : AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            Fmt.dayLabel(_date),
            verbatim: true,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _daysBack == 0 ? AppColors.ink : AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        _dayArrow(
          AppIcons.chevronRight,
          _daysBack == 0 ? null : () => setState(() => _daysBack -= 1),
        ),
      ],
      ),
    );
  }

  Widget _amountStep() {
    final empty = _digits.isEmpty;
    return Column(
      key: const ValueKey('amount'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _header('How much?'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Rs',
                    verbatim: true,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _shown,
                        verbatim: true,
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          color: empty ? AppColors.line : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Type the amount you spent',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        _dayStepper(),
        const SizedBox(height: 6),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['.', '0', '<'],
        ])
          Row(children: [for (final k in row) _keyButton(k)]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _amount > 0 ? () => setState(() => _step = 1) : null,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Next',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                const Icon(AppIcons.arrowForward, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _optionRow({
    required IconData icon,
    required String title,
    String? subtitle,
    bool selected = false,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.line,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.ink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        verbatim: true,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestionChips() {
    final list = _matching();
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in list)
              GestureDetector(
                onTap: () => _useSuggestion(g),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    g.title,
                    verbatim: true,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _titleStep(AppState s) {
    final d = _fromHistory(s) ?? _detect(s);
    return Column(
      key: const ValueKey('title'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(
          'What did you buy?',
          chip: Fmt.money(_amount),
          onChip: () => setState(() => _step = 0),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _titleNext(s),
          decoration: InputDecoration(
            hintText: tr('e.g. biryani, petrol, light bill'),
            prefixIcon: const Icon(AppIcons.editNote),
          ),
        ),
        _suggestionChips(),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: d == null
                ? Text(
                    'You can pick the category next.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.fieldFill,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CategoryStyle.icon(d.name),
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Category: ${d.name}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: () => _titleNext(s),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Next',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                const Icon(AppIcons.arrowForward, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _categoryStep(AppState s) {
    return Column(
      key: const ValueKey('category'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(
          'What was it for?',
          chip: _title.text.trim().isEmpty
              ? Fmt.money(_amount)
              : '${Fmt.money(_amount)} · $_description',
          onChip: () => setState(() => _step = 1),
        ),
        const SizedBox(height: 12),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: 60,
          ),
          children: [
            for (final c in s.categories)
              _optionRow(
                icon: CategoryStyle.icon(c.name),
                title: c.name,
                selected: _cat?.id == c.id,
                onTap: () => setState(() => _cat = c),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _cat == null ? null : () => setState(() => _step = 3),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Next',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                const Icon(AppIcons.arrowForward, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _accountStep(AppState s) {
    final bals = _bals.isNotEmpty
        ? _bals
        : [for (final a in s.accounts) AccountBalance(a, 0)];
    return Column(
      key: const ValueKey('account'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(
          'Paid from',
          chip: '${Fmt.money(_amount)} · ${tr(_cat?.name ?? '')}',
          onChip: () => setState(() => _step = 2),
        ),
        const SizedBox(height: 12),
        for (final b in bals)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _optionRow(
              icon: AccountStyle.icon(b.account.type),
              title: b.account.name,
              subtitle: _bals.isEmpty
                  ? null
                  : tr('${Fmt.money(b.balance)} available'),
              onTap: _saving ? null : () => _save(b.account),
            ),
          ),
        if (_saving)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    // Back goes one step back (what was typed stays); only the first step
    // closes the sheet.
    return PopScope(
      canPop: _step == 0 && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _saving) return;
        if (_step > 0) setState(() => _step -= 1);
      },
      child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _step == 0
                    ? _amountStep()
                    : _step == 1
                    ? _titleStep(s)
                    : _step == 2
                    ? _categoryStep(s)
                    : _accountStep(s),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
