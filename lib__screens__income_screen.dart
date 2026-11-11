import 'package:flutter/material.dart' hide Text;

import '../core/theme.dart';

import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/budget_dialog.dart';
import '../widgets/common.dart';
import '../widgets/data_loader.dart';
import '../core/i18n.dart';
import '../core/app_icons.dart';

class _IncomeData {
  final SalaryInfo salary;
  final List<Income> extras;
  _IncomeData(this.salary, this.extras);
}

/// Monthly salary (set / update) and optional other income for a month.
class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  DateTime _month = Fmt.firstOfMonth(DateTime.now());

  Future<void> _editSalary(double current) =>
      askBudget(context, forMonth: _month);

  Future<void> _addExtra() async {
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final r = await showModalBottomSheet<(double, String, int?)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _AddIncomeSheet(),
    );
    if (r == null || !mounted) return;
    final state = context.read<AppState>();
    await state.incomes.addExtra(
      r.$1,
      r.$2,
      isCurrent ? Fmt.dateOnly(now) : _month,
      accountId: r.$3,
    );
    state.changed();
    if (mounted) snackOk(context, 'Income added');
  }

  Future<void> _deleteExtra(Income i) async {
    if (!await confirmDialog(
      context,
      'Delete income?',
      '${i.source} – ${Fmt.money(i.amount)}',
    ))
      return;
    if (!mounted) return;
    final state = context.read<AppState>();
    await state.incomes.delete(i.id);
    state.changed();
    if (mounted) snackOk(context, 'Income deleted');
  }

  Widget _tile(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              verbatim: true,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budget & income')),
      body: Column(
        children: [
          MonthSwitcher(
            month: _month,
            onChanged: (m) => setState(() => _month = m),
          ),
          Expanded(
            child: DataLoader<_IncomeData>(
              depends: _month,
              load: (s) async => _IncomeData(
                await s.incomes.salaryFor(_month),
                await s.incomes.extras(_month),
              ),
              builder: (context, d) {
                final budget = d.salary.amount;
                final other = d.extras.fold<double>(0, (a, e) => a + e.amount);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradient,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Monthly budget',
                            style: TextStyle(fontSize: 13, color: Colors.white),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              Fmt.money(budget),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (d.salary.carriedFromMonth != null || budget == 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                budget == 0
                                    ? 'No budget set yet.'
                                    : 'Carried forward from ${d.salary.carriedFromMonth}. Update it if it changed.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 46,
                            child: FilledButton(
                              onPressed: () => _editSalary(budget),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF16161A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                budget == 0 ? 'Set budget' : 'Update budget',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _tile(tr('Budget'), Fmt.number(budget), AppColors.ink),
                        const SizedBox(width: 8),
                        _tile(
                          tr('Other income'),
                          '+${Fmt.number(other)}',
                          AppColors.positive,
                        ),
                        const SizedBox(width: 8),
                        _tile(
                          tr('Total'),
                          Fmt.number(budget + other),
                          AppColors.primary,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Other income',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _addExtra,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.fieldFill,
                              foregroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              minimumSize: const Size(0, 36),
                            ),
                            icon: const Icon(AppIcons.add, size: 16),
                            label: const Text(
                              'Add',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (d.extras.isEmpty)
                      AppCard(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          'None this month.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    else
                      TileGroup(
                        children: [
                          for (final i in d.extras)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 2,
                              ),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.positive.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  AppIcons.arrowDownLeft,
                                  size: 18,
                                  color: AppColors.positive,
                                ),
                              ),
                              title: Text(
                                i.source,
                                verbatim: true,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                Fmt.date(i.date),
                                verbatim: true,
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12.5,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+${Fmt.money(i.amount)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.positive,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: tr('Delete'),
                                    icon: Icon(
                                      AppIcons.delete,
                                      color: AppColors.muted,
                                    ),
                                    onPressed: () => _deleteExtra(i),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Popup to add other income: amount, where it came from, optional account.
class _AddIncomeSheet extends StatefulWidget {
  const _AddIncomeSheet();

  @override
  State<_AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends State<_AddIncomeSheet> {
  static const _sources = ['Freelance', 'Bonus', 'Gift', 'Other income'];
  final _amount = TextEditingController();
  String _source = 'Other income';
  int? _account;
  bool _error = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseAmount(_amount.text);
    if (v == null || v <= 0) {
      setState(() => _error = true);
      return;
    }
    Navigator.pop(context, (v, _source, _account));
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.muted,
      ),
    ),
  );

  Widget _chip(String label, bool on, VoidCallback onTap, {bool verbatim = false}) =>
      Material(
        color: on ? AppColors.navy : AppColors.fieldFill,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              label,
              verbatim: verbatim,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AppState>().accounts;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.positive.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.arrowDownLeft,
                  color: AppColors.positive,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add other income',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Bonus, freelance or money someone sent.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Amount',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ),
          TextField(
            controller: _amount,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [AmountFormatter()],
            onChanged: (_) {
              if (_error) setState(() => _error = false);
            },
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: 'Rs ',
              prefixStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
          if (_error)
            const Text(
              'Enter a valid amount.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          _label('Where did it come from?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final src in _sources)
                _chip(src, _source == src, () => setState(() => _source = src)),
            ],
          ),
          if (accounts.isNotEmpty) ...[
            _label('Add to account (optional)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in accounts)
                  _chip(
                    a.name,
                    _account == a.id,
                    () => setState(
                      () => _account = _account == a.id ? null : a.id,
                    ),
                    verbatim: true,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 10,
                child: SizedBox(
                  height: 54,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.fieldFill,
                      foregroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 14,
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Add income',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
