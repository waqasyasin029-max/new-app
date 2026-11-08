import 'package:flutter/material.dart' hide Text;

import '../core/account_style.dart';
import '../core/category_style.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/data_loader.dart';
import 'accounts_screen.dart';
import 'account_detail_screen.dart';
import 'expense_edit_screen.dart';
import 'history_screen.dart';
import 'income_screen.dart';
import 'settings_screen.dart';
import '../core/i18n.dart';

class _DashData {
  final SalaryInfo salary;
  final double otherIncome;
  final double monthExpenses;
  final double todayTotal;
  final List<Expense> today;
  final List<Expense> recent;
  final List<CategoryTotal> cats;
  final List<AccountBalance> accounts;
  _DashData(
    this.salary,
    this.otherIncome,
    this.monthExpenses,
    this.todayTotal,
    this.today,
    this.recent,
    this.cats,
    this.accounts,
  );
  double get income => salary.amount + otherIncome;
  double get remaining => income - monthExpenses;
  double get inAccounts => accounts.fold<double>(0, (a, b) => a + b.balance);
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
            final accounts = await s.accountRepo.balances();
            return _DashData(
              salary,
              extras.fold<double>(0, (a, e) => a + e.amount),
              spent,
              todayList.fold<double>(0, (a, e) => a + e.amount),
              todayList,
              recent,
              cats,
              accounts,
            );
          },
          builder: (context, d) => _body(context, d, now),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, _DashData d, DateTime now) {
    final negative = d.remaining < 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/icon/logo.png',
                  width: 46,
                  height: 46,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      Fmt.date(now),
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.surface,
                shape: CircleBorder(side: BorderSide(color: AppColors.line)),
                child: IconButton(
                  tooltip: tr('Settings'),
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => _open(context, const SettingsScreen()),
                ),
              ),
            ],
          ),
        ),
        // Hero banner: how much was spent today
        GestureDetector(
          onTap: () => _open(context, const HistoryScreen()),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spent today',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          Fmt.money(d.todayTotal),
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.softWhite,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          d.today.isEmpty
                              ? 'No expenses today'
                              : d.today.length == 1
                              ? '1 expense today'
                              : '${d.today.length} expenses today',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.softWhite,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _PastelTile(
              label: 'Monthly salary',
              value: Fmt.money(d.salary.amount),
              color: AppColors.mint,
              onTap: () => _open(context, const IncomeScreen()),
            ),
            const SizedBox(width: 10),
            _PastelTile(
              label: 'Spent this month',
              value: Fmt.money(d.monthExpenses),
              color: AppColors.peach,
            ),
            const SizedBox(width: 10),
            _PastelTile(
              label: 'Left of salary',
              value: Fmt.money(d.remaining),
              color: AppColors.sky,
              valueColor: negative ? AppColors.danger : null,
            ),
          ],
        ),
        if (d.salary.amount == 0)
          AppCard(
            color: AppColors.noteBg,
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
              subtitle: Text(
                'Needed to calculate what is left of your salary.',
              ),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 0, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your accounts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () => _open(context, const AccountsScreen()),
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: d.accounts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final b = d.accounts[i];
              return SizedBox(
                width: 150,
                child: Material(
                  color: AccountStyle.tint(b.account.type),
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _open(
                      context,
                      AccountDetailScreen(accountId: b.account.id),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(AccountStyle.icon(b.account.type), size: 24),
                          const Spacer(),
                          Text(
                            b.account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              Fmt.money(b.balance),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: b.balance < 0
                                    ? AppColors.danger
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SectionTitle('Categories this month'),
        const SizedBox(height: 6),
        if (d.cats.isEmpty)
          Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Spending by category will appear here.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          SizedBox(
            height: 104,
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
          AppCard(
            padding: EdgeInsets.all(18),
            child: Text(
              'No expenses recorded today. Tap the plus button to add one.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          TileGroup(children: [for (final e in d.today) _tile(context, e)]),
        const SectionTitle('Recent transactions'),
        if (d.recent.isEmpty)
          AppCard(
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

class _PastelTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color? valueColor;
  final VoidCallback? onTap;
  const _PastelTile({
    required this.label,
    required this.value,
    required this.color,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
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
            style: TextStyle(color: AppColors.muted, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}
