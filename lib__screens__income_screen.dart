import 'package:flutter/material.dart' hide Text;

import '../core/theme.dart';

import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../state/app_state.dart';
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

  Future<void> _editSalary(double current) async {
    final c = TextEditingController(
      text: current > 0 ? Fmt.number(current).replaceAll(',', '') : '',
    );
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Budget for ${Fmt.month(_month)}'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: tr('Amount (Rs)')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final a = parseAmount(c.text);
              if (a == null) {
                snack(ctx, 'Enter a valid amount.');
                return;
              }
              Navigator.pop(ctx, a);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (v == null || !mounted) return;
    final state = context.read<AppState>();
    await state.incomes.setSalary(_month, v);
    state.changed();
  }

  Future<void> _addExtra() async {
    final amount = TextEditingController();
    final source = TextEditingController();
    int? accId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add other income'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: tr('Amount (Rs)')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: source,
              decoration: InputDecoration(
                labelText: tr('Source (bonus, freelance…)'),
              ),
            ),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (c, setD) => AccountDropdown(
                label: 'Add to account (optional)',
                value: accId,
                allowNone: true,
                onChanged: (v) => setD(() => accId = v),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (parseAmount(amount.text) == null) {
                snack(ctx, 'Enter a valid amount.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final a = parseAmount(amount.text);
    final s = source.text.trim();
    amount.dispose();
    source.dispose();
    if (ok != true || a == null || !mounted) return;
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final state = context.read<AppState>();
    await state.incomes.addExtra(
      a,
      s.isEmpty ? 'Other income' : s,
      isCurrent ? Fmt.dateOnly(now) : _month,
      accountId: accId,
    );
    state.changed();
  }

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
              builder: (context, d) => ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly budget',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Fmt.money(d.salary.amount),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (d.salary.carriedFromMonth != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Carried forward from ${d.salary.carriedFromMonth}. Update it if it changed.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          if (d.salary.amount == 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'No budget set yet.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => _editSalary(d.salary.amount),
                            icon: const Icon(AppIcons.edit),
                            label: Text(
                              d.salary.amount == 0
                                  ? 'Set budget'
                                  : 'Update budget',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Other income',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton.icon(
                        onPressed: _addExtra,
                        icon: const Icon(AppIcons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  if (d.extras.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('None this month.'),
                    )
                  else
                    for (final i in d.extras)
                      AppCard(
                        child: ListTile(
                          leading: const Icon(
                            AppIcons.addCircle,
                            color: Colors.green,
                          ),
                          title: Text(i.source, verbatim: true),
                          subtitle: Text(Fmt.date(i.date)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Fmt.money(i.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(AppIcons.delete),
                                onPressed: () async {
                                  if (!await confirmDialog(
                                    context,
                                    'Delete income?',
                                    '${i.source} – ${Fmt.money(i.amount)}',
                                  ))
                                    return;
                                  final state = context.read<AppState>();
                                  await state.incomes.delete(i.id);
                                  state.changed();
                                },
                              ),
                            ],
                          ),
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
}
