import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../logic/account_matcher.dart';
import '../logic/expense_parser.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../core/i18n.dart';
import '../widgets/date_sheet.dart';
import '../core/app_icons.dart';

class _Draft {
  final TextEditingController amount;
  final TextEditingController desc;
  final String heard;
  int categoryId;
  int? accountId;
  bool include = true;
  final bool amountMissing;

  _Draft({
    required double? amt,
    required String description,
    required this.categoryId,
    required this.heard,
    this.accountId,
  }) : amount = TextEditingController(
         text: amt == null ? '' : Fmt.number(amt).replaceAll(',', ''),
       ),
       desc = TextEditingController(text: description),
       amountMissing = amt == null;

  double? get value => parseAmount(amount.text);
  void dispose() {
    amount.dispose();
    desc.dispose();
  }
}

/// Shows detected expenses for review. Nothing is written to the database
/// until the user presses "Save". Every expense must have a "Paid from" account.
class ConfirmExpensesScreen extends StatefulWidget {
  final String rawText;
  final ParseResult result;
  const ConfirmExpensesScreen({
    super.key,
    required this.rawText,
    required this.result,
  });

  /// Opens the review as a pop-up sheet over the current screen instead of a
  /// new page. Completes with true once the expenses were saved.
  static Future<bool?> show(
    BuildContext context, {
    required String rawText,
    required ParseResult result,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.92,
        child: ConfirmExpensesScreen(rawText: rawText, result: result),
      ),
    );
  }

  @override
  State<ConfirmExpensesScreen> createState() => _ConfirmExpensesScreenState();
}

class _ConfirmExpensesScreenState extends State<ConfirmExpensesScreen> {
  final List<_Draft> _drafts = [];
  DateTime _date = Fmt.dateOnly(DateTime.now());
  bool _saving = false;
  int? _allAccount;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final accs = [for (final a in state.accounts) (id: a.id, name: a.name)];
    final perItem = <int?>[
      for (final p in widget.result.items)
        AccountMatcher.match(p.sourceText, accs),
    ];
    // If no single item named an account but the whole sentence names exactly one, use it for all.
    final whole = perItem.every((x) => x == null)
        ? AccountMatcher.match(widget.rawText, accs)
        : null;
    for (var i = 0; i < widget.result.items.length; i++) {
      final p = widget.result.items[i];
      final acc = perItem[i] ?? whole;
      var desc = p.description;
      if (acc != null) {
        final stripped = AccountMatcher.strip(desc, accs);
        desc = stripped.isEmpty
            ? desc
            : stripped[0].toUpperCase() + stripped.substring(1);
      }
      _drafts.add(
        _Draft(
          amt: p.amount,
          description: desc,
          categoryId: state.categoryByName(p.category).id,
          heard: p.sourceText,
          accountId: acc,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Iterable<_Draft> get _included => _drafts.where((d) => d.include);
  bool get _canSave =>
      _included.isNotEmpty &&
      _included.every((d) => d.value != null && d.accountId != null);
  double get _total => _included.fold<double>(0, (a, d) => a + (d.value ?? 0));

  void _addBlank() {
    final state = context.read<AppState>();
    setState(
      () => _drafts.add(
        _Draft(
          amt: null,
          description: '',
          categoryId: state.categoryByName('Other').id,
          heard: '(added by you)',
          accountId: _allAccount,
        ),
      ),
    );
  }

  void _setAll(int id) => setState(() {
    _allAccount = id;
    for (final d in _drafts) {
      d.accountId = id;
    }
  });

  Future<void> _pickDate() async {
    final d = await showDateSheet(
      context,
      initial: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = Fmt.dateOnly(d));
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final list = <Expense>[
      for (final d in _included)
        Expense(
          amount: d.value!,
          categoryId: d.categoryId,
          accountId: d.accountId,
          description: d.desc.text.trim().isEmpty
              ? (state.categoryById(d.categoryId)?.name ?? 'Expense')
              : d.desc.text.trim(),
          date: _date,
          source: 'voice',
          rawText: widget.rawText,
        ),
    ];
    try {
      await state.expenses.insertMany(list);
      state.changed();
      final total = list.fold<double>(0, (a, e) => a + e.amount);
      final used = {for (final e in list) e.accountId!};
      final bals = await state.accountRepo.balances();
      final left = [
        for (final b in bals)
          if (used.contains(b.account.id))
            tr('${b.account.name} left ${Fmt.money(b.balance)}'),
      ].join(' • ');
      nav.pop(true);
      showOk(
        messenger,
        message:
            'Saved ${list.length} expense${list.length == 1 ? '' : 's'} • ${Fmt.money(total)}\n$left',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        snack(context, 'Could not save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final missingAmt = _included.where((d) => d.value == null).length;
    final missingAcc = _included.where((d) => d.accountId == null).length;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Confirm expenses'),
        actions: [
          IconButton(
            tooltip: tr('Close'),
            icon: const Icon(AppIcons.close),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You said',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.rawText),
                    ],
                  ),
                ),
                if (widget.result.items.isEmpty)
                  AppCard(
                    color: scheme.errorContainer,
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'No expenses with amounts were recognised. Go back and correct the text, or add an expense below.',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                if (widget.result.ignored.isNotEmpty)
                  AppCard(
                    color: scheme.tertiaryContainer,
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Not understood (not saved): ${widget.result.ignored.join(' • ')}',
                      style: TextStyle(color: scheme.onTertiaryContainer),
                    ),
                  ),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paid from (apply to all)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      AccountChips(
                        selectedId: _allAccount,
                        onSelected: _setAll,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cash, a wallet or a bank. You can change it per expense below.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(AppIcons.calendar, size: 18),
                  label: Text('Date for all: ${Fmt.date(_date)}'),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _drafts.length; i++) _draftCard(i, scheme),
                TextButton.icon(
                  onPressed: _addBlank,
                  icon: const Icon(AppIcons.add),
                  label: const Text('Add another expense'),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: const [
                  BoxShadow(blurRadius: 8, color: Colors.black12),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _included.length == 1
                              ? '1 expense'
                              : '${_included.length} expenses',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        Text(
                          Fmt.money(_total),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (missingAmt > 0)
                          Text(
                            '$missingAmt need an amount',
                            style: TextStyle(color: scheme.error, fontSize: 12),
                          ),
                        if (missingAcc > 0)
                          Text(
                            '$missingAcc need "Paid from"',
                            style: TextStyle(color: scheme.error, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _canSave && !_saving ? _save : null,
                    icon: const Icon(AppIcons.check),
                    label: const Text('Save'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(130, 52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _draftCard(int i, ColorScheme scheme) {
    final d = _drafts[i];
    final needsAmount = d.include && d.value == null;
    final needsAccount = d.include && d.accountId == null;
    return AppCard(
      color: d.include ? null : AppColors.disabledBg,
      borderColor: (needsAmount || needsAccount) ? scheme.error : null,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: d.include,
                onChanged: (v) => setState(() => d.include = v ?? true),
              ),
              Expanded(
                child: Text(
                  'Heard: ${d.heard}',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(AppIcons.close),
                tooltip: tr('Remove'),
                onPressed: () => setState(() => _drafts.removeAt(i).dispose()),
              ),
            ],
          ),
          if (d.include) ...[
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: d.amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [AmountFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: tr('Amount (Rs)'),
                      errorText: needsAmount
                          ? (d.amountMissing
                                ? tr('Amount not heard: enter it')
                                : tr('Invalid amount'))
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: d.desc,
                    decoration: InputDecoration(labelText: tr('Description')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CategoryDropdown(
              value: d.categoryId,
              onChanged: (v) =>
                  setState(() => d.categoryId = v ?? d.categoryId),
            ),
            const SizedBox(height: 10),
            AccountDropdown(
              value: d.accountId,
              errorText: needsAccount ? tr('Choose where you paid from') : null,
              onChanged: (v) => setState(() => d.accountId = v),
            ),
          ],
        ],
      ),
    );
  }
}
