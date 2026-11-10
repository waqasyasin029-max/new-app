import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/account_style.dart';
import '../core/category_style.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/data_loader.dart';
import 'accounts_screen.dart';
import 'account_detail_screen.dart';
import 'expense_edit_screen.dart';
import 'history_screen.dart';
import '../widgets/budget_dialog.dart';
import 'reminders_screen.dart';
import '../core/i18n.dart';
import '../core/app_icons.dart';

class _DashData {
  final SalaryInfo salary;
  final double otherIncome;
  final double monthExpenses;
  final double todayTotal;
  final List<Expense> today;
  final List<Expense> week;
  final List<Expense> earlier;
  final List<CategoryTotal> cats;
  final List<AccountBalance> accounts;
  _DashData(
    this.salary,
    this.otherIncome,
    this.monthExpenses,
    this.todayTotal,
    this.today,
    this.week,
    this.earlier,
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
            final weekStart = today.subtract(const Duration(days: 6));
            final week = await s.expenses.list(from: weekStart, to: today);
            final earlier = await s.expenses.list(
              to: weekStart.subtract(const Duration(days: 1)),
              limit: 4,
            );
            final cats = await s.expenses.categoryTotals(month, end);
            final accounts = await s.accountRepo.balances();
            return _DashData(
              salary,
              extras.fold<double>(0, (a, e) => a + e.amount),
              spent,
              todayList.fold<double>(0, (a, e) => a + e.amount),
              todayList,
              week,
              earlier,
              cats,
              accounts,
            );
          },
          builder: (context, d) => _body(context, d, now),
        ),
      ),
    );
  }

  /// This month's budget: how much is left, with a bar. Tap to change it.
  Widget _budgetCard(BuildContext context, _DashData d) {
    final budget = d.salary.amount;
    if (budget <= 0) {
      return AppCard(
        color: AppColors.noteBg,
        onTap: () => askBudget(context),
        child: const ListTile(
          leading: Icon(AppIcons.wallet, color: AppColors.gold),
          title: Text(
            'Set your monthly budget',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('Needed to see how much of your budget is left.'),
          trailing: Icon(AppIcons.chevronRight),
        ),
      );
    }
    final left = budget - d.monthExpenses;
    final over = left < 0;
    final used = (d.monthExpenses / budget).clamp(0.0, 1.0);
    final warn = d.monthExpenses / budget >= 0.8;
    final pct = (d.monthExpenses / budget * 100).floor();
    return AppCard(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      onTap: () => askBudget(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Monthly budget',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                Fmt.money(budget),
                verbatim: true,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            over
                ? '${Fmt.money(-left)} over budget'
                : '${Fmt.money(left)} left of budget',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: over ? AppColors.danger : AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: used,
              minHeight: 10,
              backgroundColor: warn
                  ? AppColors.danger.withOpacity(0.15)
                  : AppColors.line,
              color: warn ? AppColors.danger : AppColors.primary,
            ),
          ),
          if (warn)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(AppIcons.info, size: 20, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      over
                          ? 'Budget is over. Spend only on what is really needed.'
                          : 'Budget is $pct% used. Only ${Fmt.money(left)} left, spend carefully.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '${Fmt.money(d.monthExpenses)} spent this month',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  /// Greeting for the time of day.
  String _greeting(DateTime now) {
    final h = now.hour;
    if (h >= 5 && h < 12) return 'Good Morning';
    if (h >= 12 && h < 17) return 'Good Afternoon';
    if (h >= 17 && h < 21) return 'Good Evening';
    return 'Good Night';
  }

  Widget _body(BuildContext context, _DashData d, DateTime now) {
    final name = context.select<AppState, String>((s) => s.userName);
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
                    if (name.isNotEmpty)
                      Text(
                        'Hello, $name',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      _greeting(now),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.surface,
                shape: CircleBorder(side: BorderSide(color: AppColors.line)),
                child: IconButton(
                  tooltip: tr('Reminders'),
                  icon: const Icon(AppIcons.bellRinging),
                  onPressed: () => _open(context, const RemindersScreen()),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title on one side, the date pill on the far other side of
                // the whole card.
                Row(
                  children: [
                    const Text(
                      'Spent today',
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.softWhite,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        Fmt.date(now),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                        AppIcons.payments,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _budgetCard(context, d),
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
        const SectionTitle('Recent'),
        if (d.today.isEmpty)
          AppCard(
            padding: EdgeInsets.all(18),
            child: Text(
              'No expenses recorded today. Tap the plus button to add one.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ..._dayGroups(context, d),
        if (d.earlier.isNotEmpty) ...[
          _dayHeader('Earlier', null),
          TileGroup(
            children: [
              for (final e in d.earlier) _tile(context, e, showDate: true),
            ],
          ),
        ],
        if (d.week.isNotEmpty || d.earlier.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton(
              onPressed: () => _open(context, const HistoryScreen()),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'See all in History',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
            ),
          ),
      ],
    );
  }

  /// One header + card per day (last 7 days, only days that have expenses).
  List<Widget> _dayGroups(BuildContext context, _DashData d) {
    final days = <String, List<Expense>>{};
    for (final e in d.week) {
      days.putIfAbsent(Fmt.key(e.date), () => []).add(e);
    }
    return [
      for (final entry in days.entries) ...[
        _dayHeader(
          Fmt.dayLabel(Fmt.parseKey(entry.key)),
          Fmt.money(entry.value.fold<double>(0, (a, e) => a + e.amount)),
          verbatim: true,
        ),
        TileGroup(children: [for (final e in entry.value) _tile(context, e)]),
      ],
    ];
  }

  Widget _dayHeader(String label, String? total, {bool verbatim = false}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              verbatim: verbatim,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            if (total != null)
              Text(
                total,
                verbatim: true,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
          ],
        ),
      );

  Widget _tile(BuildContext context, Expense e, {bool showDate = false}) =>
      ExpenseTile(
        expense: e,
        showDate: showDate,
        onTap: () => _open(context, ExpenseEditScreen(expense: e)),
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
