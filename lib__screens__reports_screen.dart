import 'package:flutter/material.dart';

import '../core/category_style.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/data_loader.dart';

class _ReportData {
  final double income;
  final double spent;
  final List<CategoryTotal> cats;
  final Map<String, double> daily;
  _ReportData(this.income, this.spent, this.cats, this.daily);
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _month = Fmt.firstOfMonth(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          MonthSwitcher(
            month: _month,
            onChanged: (m) => setState(() => _month = m),
          ),
          Expanded(
            child: DataLoader<_ReportData>(
              depends: _month,
              load: (s) async {
                final from = _month;
                final to = Fmt.lastOfMonth(_month);
                return _ReportData(
                  await s.incomes.totalIncome(_month),
                  await s.expenses.total(from, to),
                  await s.expenses.categoryTotals(from, to),
                  await s.expenses.dailyTotals(from, to),
                );
              },
              builder: (context, d) {
                final remaining = d.income - d.spent;
                final daysInMonth = Fmt.lastOfMonth(_month).day;
                final now = DateTime.now();
                final isCurrent =
                    _month.year == now.year && _month.month == now.month;
                final elapsed = isCurrent ? now.day : daysInMonth;
                final maxDay = d.daily.values.fold<double>(
                  0,
                  (a, b) => b > a ? b : a,
                );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Income',
                            value: Fmt.money(d.income),
                            icon: Icons.payments,
                          ),
                        ),
                        Expanded(
                          child: StatCard(
                            label: 'Expenses',
                            value: Fmt.money(d.spent),
                            icon: Icons.trending_down,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Remaining',
                            value: Fmt.money(remaining),
                            icon: Icons.savings,
                            color: remaining < 0
                                ? AppColors.danger
                                : AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: StatCard(
                            label: 'Avg per day',
                            value: Fmt.money(d.spent / elapsed),
                            icon: Icons.calendar_view_day,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: SectionTitle('Spending by category'),
                    ),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: d.cats.isEmpty
                          ? const Text(
                              'No expenses this month.',
                              style: TextStyle(color: AppColors.muted),
                            )
                          : Column(
                              children: [
                                for (final c in d.cats)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 7,
                                    ),
                                    child: Row(
                                      children: [
                                        CategoryAvatar(c.name, radius: 17),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    '${c.name} (${c.count})',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${Fmt.money(c.total)} • ${(c.total / d.spent * 100).toStringAsFixed(0)}%',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              LinearProgressIndicator(
                                                value: c.total / d.spent,
                                                minHeight: 7,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                backgroundColor:
                                                    CategoryStyle.color(c.name)
                                                        .withOpacity(0.12),
                                                color: CategoryStyle.color(
                                                  c.name,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: SectionTitle('Daily breakdown'),
                    ),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: d.daily.isEmpty
                          ? const Text(
                              'No expenses this month.',
                              style: TextStyle(color: AppColors.muted),
                            )
                          : Column(
                              children: [
                                for (final day
                                    in d.daily.keys.toList().reversed)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 56,
                                          child: Text(
                                            Fmt.dayShort(Fmt.parseKey(day)),
                                            style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: d.daily[day]! / maxDay,
                                            minHeight: 10,
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                            backgroundColor: AppColors.primary
                                                .withOpacity(0.12),
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 92,
                                          child: Text(
                                            Fmt.money(d.daily[day]!),
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
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
