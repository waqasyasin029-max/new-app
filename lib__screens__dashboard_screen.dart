import 'package:flutter/material.dart';

import '../core/category_style.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/data_loader.dart';
import 'expense_edit_screen.dart';
import 'history_screen.dart';
import 'income_screen.dart';

class _DashData {
  final SalaryInfo salary;
  final double otherIncome;
  final double monthExpenses;
  final double todayTotal;
  final List<Expense> today;
  final List<Expense> recent;
  final List<CategoryTotal> cats;
  _DashData(
    this.salary,
    this.otherIncome,
    this.monthExpenses,
    this.todayTotal,
    this.today,
    this.recent,
    this.cats,
  );
  double get income => salary.amount + otherIncome;
  double get remaining => income - monthExpenses;
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = Fmt.dateOnly(now);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: DataLoader<_DashData>(
          depends: Fmt.key(today),
          load: (s) async {
            final month = Fmt.firstOfMonth(now);
            final end = Fmt.lastOfMonth(now);
            final salary = await s.incomes.salaryFor(month);
            final extras = await s.incomes.extras(month);
            final spent = await s.expenses.total(month, end);
            final todayList = await s.expenses.list(from: today, to: today);
            final recent = await s.expenses.list(limit: 8);
            final cats = await s.expenses.categoryTotals(month, end);
            return _DashData(
              salary,
              extras.fold<double>(0, (a, e) => a + e.amount),
              spent,
              todayList.fold<double>(0, (a, e) => a + e.amount),
              todayList,
              recent,
              cats,
            );
          },
          builder: (context, d) => _body(context, d, now),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, _DashData d, DateTime now) {
    final negative = d.remaining < 0;
    final ratio = d.income > 0
        ? (d.monthExpenses / d.income).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final ringColor = ratio > 0.9 ? AppColors.danger : AppColors.primary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      Fmt.month(now),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 44,
                  height: 44,
                ),
              ),
            ],
          ),
        ),
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  ProgressRing(
                    value: ratio,
                    label: '${(ratio * 100).round()}%',
                    caption: 'spent',
                    color: ringColor,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Remaining balance',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Fmt.money(d.remaining),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: negative
                                  ? AppColors.danger
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.income > 0
                              ? 'of ${Fmt.money(d.income)} income'
                              : 'Set your salary to begin',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniStat(
                    label: 'Monthly salary',
                    value: Fmt.money(d.salary.amount),
                    onTap: () => _open(context, const IncomeScreen()),
                  ),
                  Container(width: 1, height: 36, color: AppColors.line),
                  _MiniStat(
                    label: 'Spent this month',
                    value: Fmt.money(d.monthExpenses),
                    color: Colors.deepOrange,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (d.salary.amount == 0)
          AppCard(
            color: const Color(0xFFFFF6DC),
            onTap: () => _open(context, const IncomeScreen()),
            child: const ListTile(
              leading: Icon(
                Icons.account_balance_wallet,
                color: AppColors.gold,
              ),
              title: Text(
                'Set your monthly salary',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Needed to calculate your remaining balance.'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        const SectionTitle('Categories this month'),
        const SizedBox(height: 6),
        if (d.cats.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Spending by category will appear here.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: d.cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _CategoryTile(
                total: d.cats[i],
                onTap: () => _open(
                  context,
                  HistoryScreen(initialCategoryId: d.cats[i].id),
                ),
              ),
            ),
          ),
        SectionTitle('Today', trailing: Fmt.money(d.todayTotal)),
        if (d.today.isEmpty)
          const AppCard(
            padding: EdgeInsets.all(18),
            child: Text(
              'No expenses recorded today. Tap the mic and speak them.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          TileGroup(children: [for (final e in d.today) _tile(context, e)]),
        const SectionTitle('Recent transactions'),
        if (d.recent.isEmpty)
          const AppCard(
            padding: EdgeInsets.all(18),
            child: Text(
              'Nothing yet.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          TileGroup(
            children: [
              for (final e in d.recent) _tile(context, e, showDate: true),
            ],
          ),
      ],
    );
  }

  Widget _tile(BuildContext context, Expense e, {bool showDate = false}) =>
      ExpenseTile(
        expense: e,
        showDate: showDate,
        onTap: () => _open(context, ExpenseEditScreen(expense: e)),
      );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final VoidCallback? onTap;
  const _MiniStat({
    required this.label,
    required this.value,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: color ?? AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  final CategoryTotal total;
  final VoidCallback onTap;
  const _CategoryTile({required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    child: AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CategoryStyle.icon(total.name),
            color: CategoryStyle.color(total.name),
            size: 26,
          ),
          const Spacer(),
          Text(
            total.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            Fmt.money(total.total),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}
