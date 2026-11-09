import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/category_style.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../services/report_pdf_service.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/data_loader.dart';
import '../widgets/pdf_sheet.dart';
import '../widgets/report_charts.dart';
import 'income_screen.dart';
import '../core/i18n.dart';
import '../core/app_icons.dart';

class _ReportData {
  final double salary;
  final double income;
  final double spent;
  final List<CategoryTotal> cats;
  final Map<String, double> daily;
  final List<MonthPoint> months;
  _ReportData(
    this.salary,
    this.income,
    this.spent,
    this.cats,
    this.daily,
    this.months,
  );
}

class ReportsScreen extends StatefulWidget {
  /// True inside the Activity tab, which draws the title bar itself.
  final bool embedded;
  const ReportsScreen({super.key, this.embedded = false});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _month = Fmt.firstOfMonth(DateTime.now());
  bool _pdfBusy = false;

  Future<void> _savePdf() async {
    if (_pdfBusy) return;
    final s = context.read<AppState>();
    var firstYear = DateTime.now().year;
    try {
      final first = await s.expenses.firstDate();
      if (first != null && first.year < firstYear) firstYear = first.year;
    } catch (_) {}
    if (!mounted) return;
    final choice = await showPdfSheet(
      context,
      month: _month,
      firstYear: firstYear,
    );
    if (choice == null || !mounted) return;
    setState(() => _pdfBusy = true);
    try {
      await ReportPdfService.openMonth(
        s,
        choice.month,
        wholeYear: choice.wholeYear,
      );
    } catch (_) {
      if (mounted) {
        snack(context, 'Could not create the PDF. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Reports')),
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
                // The selected month and the five before it, for the charts.
                final months = <MonthPoint>[];
                for (var i = 5; i >= 0; i--) {
                  final m = DateTime(_month.year, _month.month - i, 1);
                  months.add(
                    MonthPoint(
                      m,
                      (await s.incomes.salaryFor(m)).amount,
                      await s.expenses.total(m, Fmt.lastOfMonth(m)),
                    ),
                  );
                }
                return _ReportData(
                  (await s.incomes.salaryFor(_month)).amount,
                  (await s.incomes.salaryFor(_month)).amount,
                  await s.expenses.total(from, to),
                  await s.expenses.categoryTotals(from, to),
                  await s.expenses.dailyTotals(from, to),
                  months,
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
                    AppCard(
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                      child: SpendingChartCard(
                        key: ValueKey(_month),
                        month: _month,
                        daily: d.daily,
                        budget: d.income,
                        perDay: d.spent / elapsed,
                        months: d.months,
                      ),
                    ),
                    _SummaryCard(
                      budget: d.income,
                      spent: d.spent,
                      perDay: d.spent / elapsed,
                    ),
                    AppCard(
                      margin: const EdgeInsets.all(4),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const IncomeScreen()),
                      ),
                      child: ListTile(
                        leading: const Icon(AppIcons.payments),
                        title: const Text(
                          'Monthly budget',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(Fmt.money(d.salary), verbatim: true),
                        trailing: const Icon(AppIcons.chevronRight),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                      child: OutlinedButton.icon(
                        onPressed: _pdfBusy ? null : _savePdf,
                        icon: _pdfBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Icon(AppIcons.receipt, size: 20),
                        label: Text(
                          _pdfBusy ? 'Creating PDF...' : 'Save report as PDF',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: SectionTitle('Spending by category'),
                    ),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: d.cats.isEmpty
                          ? Text(
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
                          ? Text(
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
                                            style: TextStyle(
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
                                            textAlign: TextAlign.end,
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

/// Budget, expenses and what is left, together in one short card.
class _SummaryCard extends StatelessWidget {
  final double budget;
  final double spent;
  final double perDay;
  const _SummaryCard({
    required this.budget,
    required this.spent,
    required this.perDay,
  });

  Widget _col(IconData icon, String label, String value, Color color,
      String caption) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              verbatim: true,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = budget - spent;
    final over = remaining < 0;
    final used = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final barColor = over ? AppColors.danger : AppColors.primary;
    return AppCard(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _col(
                  AppIcons.trendUp,
                  'Budget',
                  Fmt.money(budget),
                  AppColors.positive,
                  'Your plan for the month',
                ),
                VerticalDivider(width: 24, thickness: 1, color: AppColors.line),
                _col(
                  AppIcons.trendDown,
                  'Expenses',
                  Fmt.money(spent),
                  AppColors.danger,
                  '${Fmt.money(perDay)} per day',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: used,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: barColor.withOpacity(0.12),
            color: barColor,
          ),
          const SizedBox(height: 8),
          Text(
            over
                ? '${Fmt.money(-remaining)} over budget'
                : '${Fmt.money(remaining)} left of budget',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: over ? AppColors.danger : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
