import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/data_loader.dart';
import 'expense_edit_screen.dart';
import 'income_screen.dart';

class _DashData {
  final SalaryInfo salary;
  final double otherIncome;
  final double monthExpenses;
  final double todayTotal;
  final List<Expense> today;
  final List<Expense> recent;
  _DashData(
    this.salary,
    this.otherIncome,
    this.monthExpenses,
    this.todayTotal,
    this.today,
    this.recent,
  );
  double get income => salary.amount + otherIncome;
  double get remaining => income - monthExpenses;
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = Fmt.dateOnly(now);
    return Scaffold(
      appBar: AppBar(title: Text(Fmt.month(now))),
      body: DataLoader<_DashData>(
        depends: Fmt.key(today),
        load: (s) async {
          final month = Fmt.firstOfMonth(now);
          final salary = await s.incomes.salaryFor(month);
          final extras = await s.incomes.extras(month);
          final spent = await s.expenses.total(month, Fmt.lastOfMonth(now));
          final todayList = await s.expenses.list(from: today, to: today);
          final recent = await s.expenses.list(limit: 8);
          return _DashData(
            salary,
            extras.fold<double>(0, (a, e) => a + e.amount),
            spent,
            todayList.fold<double>(0, (a, e) => a + e.amount),
            todayList,
            recent,
          );
        },
        builder: (context, d) {
          final negative = d.remaining < 0;
          final ratio = d.income > 0
              ? (d.monthExpenses / d.income).clamp(0.0, 1.0)
              : 0.0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
            children: [
              if (d.salary.amount == 0)
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: const Text('Set your monthly salary'),
                    subtitle: const Text(
                      'Needed to calculate your remaining balance.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const IncomeScreen()),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const IncomeScreen()),
                      ),
                      child: StatCard(
                        label: 'Monthly salary',
                        value: Fmt.money(d.salary.amount),
                        icon: Icons.payments,
                      ),
                    ),
                  ),
                  Expanded(
                    child: StatCard(
                      label: 'Spent this month',
                      value: Fmt.money(d.monthExpenses),
                      icon: Icons.trending_down,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
              StatCard(
                label: 'Remaining balance',
                value: Fmt.money(d.remaining),
                icon: Icons.savings,
                color: negative ? Colors.red : Colors.green.shade700,
              ),
              if (d.income > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                        color: ratio > 0.9 ? Colors.red : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(d.monthExpenses / d.income * 100).toStringAsFixed(0)}% of income spent'
                        '${d.otherIncome > 0 ? ' (incl. ${Fmt.money(d.otherIncome)} other income)' : ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _SectionHeader('Today', trailing: Fmt.money(d.todayTotal)),
              if (d.today.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No expenses recorded today. Tap the mic and speak them.',
                  ),
                )
              else
                for (final e in d.today) _tile(context, e),
              const SizedBox(height: 12),
              const _SectionHeader('Recent transactions'),
              if (d.recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nothing yet.'),
                )
              else
                for (final e in d.recent) _tile(context, e, showDate: true),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, Expense e, {bool showDate = false}) =>
      Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: ExpenseTile(
          expense: e,
          showDate: showDate,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ExpenseEditScreen(expense: e)),
          ),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
      ],
    ),
  );
}
