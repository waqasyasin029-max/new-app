import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/data_loader.dart';
import 'add_expense_flow.dart';
import 'expense_edit_screen.dart';
import '../core/i18n.dart';
import '../widgets/date_sheet.dart';
import '../widgets/report_charts.dart';
import '../core/app_icons.dart';

class HistoryScreen extends StatefulWidget {
  final int? initialCategoryId;

  /// True inside the Activity tab, which draws the title bar itself.
  final bool embedded;
  const HistoryScreen({
    super.key,
    this.initialCategoryId,
    this.embedded = false,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTimeRange? _range;
  late int? _categoryId = widget.initialCategoryId;
  String _search = '';

  static const _chartWeeks = 8;
  int _chartPage = 0;

  DateTime? get _singleDay {
    final r = _range;
    if (r == null) return null;
    return Fmt.dateOnly(r.start) == Fmt.dateOnly(r.end)
        ? Fmt.dateOnly(r.start)
        : null;
  }

  /// The last-7-days bars at the top of the list.
  Widget _weekChart() {
    return DataLoader<Map<String, double>>(
      load: (s) {
        final t = Fmt.dateOnly(DateTime.now());
        final from = DateTime(t.year, t.month, t.day - (7 * _chartWeeks - 1));
        return s.expenses.dailyTotals(from, t);
      },
      builder: (context, daily) => WeekBarsCard(
        daily: daily,
        weeks: _chartWeeks,
        selectedDay: _singleDay,
        initialPage: _chartPage,
        onPageChanged: (i) => _chartPage = i,
        onPickDay: (d) => setState(() {
          _range = _singleDay == d ? null : DateTimeRange(start: d, end: d);
        }),
      ),
    );
  }

  bool get _filtered =>
      _range != null || _categoryId != null || _search.isNotEmpty;

  Future<void> _pickRange() async {
    final r = await showDateRangeSheet(
      context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initial: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('History'),
              actions: [
                IconButton(
                  tooltip: tr('Add expense'),
                  icon: const Icon(AppIcons.addCircle),
                  onPressed: () => AddExpenseFlow.start(context),
                ),
              ],
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child:
                TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(AppIcons.search),
                          hintText: tr('Search'),
                          fillColor: AppColors.fieldFill,
                          border: pillBorder(),
                          enabledBorder: pillBorder(),
                          focusedBorder: pillBorder(),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    if (widget.embedded) ...[
                      const SizedBox(width: 8),
                      Material(
                        color: AppColors.surface,
                        shape: CircleBorder(
                          side: BorderSide(color: AppColors.line),
                        ),
                        child: IconButton(
                          tooltip: tr('Add expense'),
                          icon: const Icon(AppIcons.addCircle),
                          onPressed: () => AddExpenseFlow.start(context),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickRange,
                        icon: const Icon(AppIcons.dateRange, size: 18),
                        label: Text(
                          _range == null
                              ? 'Any date'
                              : '${Fmt.dayShort(_range!.start)} – ${Fmt.dayShort(_range!.end)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 56),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CategoryDropdown(
                        value: _categoryId,
                        allowAll: true,
                        label: 'Category',
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    ),
                  ],
                ),
                if (_filtered)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _range = null;
                        _categoryId = null;
                        _search = '';
                      }),
                      icon: const Icon(AppIcons.clear, size: 18),
                      label: const Text('Clear filters'),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: DataLoader<List<Expense>>(
              depends: (_range, _categoryId, _search),
              load: (s) => s.expenses.list(
                from: _range?.start,
                to: _range?.end,
                categoryId: _categoryId,
                search: _search,
              ),
              builder: (context, list) {
                if (list.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    children: [
                      _weekChart(),
                      const SizedBox(height: 40),
                      Center(
                        child: Text(
                          _filtered
                              ? 'No transactions match these filters.'
                              : 'No transactions yet.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  );
                }
                final total = list.fold<double>(0, (a, e) => a + e.amount);
                final byDay = <String, List<Expense>>{};
                for (final e in list) {
                  byDay.putIfAbsent(Fmt.key(e.date), () => []).add(e);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                  children: [
                    _weekChart(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Text(
                        '${list.length} transactions • ${Fmt.money(total)}',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                    for (final day in byDay.keys) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              Fmt.date(Fmt.parseKey(day)),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              Fmt.money(
                                byDay[day]!.fold<double>(
                                  0,
                                  (a, e) => a + e.amount,
                                ),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TileGroup(
                        children: [
                          for (final e in byDay[day]!)
                            ExpenseTile(
                              expense: e,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ExpenseEditScreen(expense: e),
                                ),
                              ),
                              onDelete: () async {
                                final label = e.description.isEmpty
                                    ? (e.categoryName ?? 'Expense')
                                    : e.description;
                                if (!await confirmDialog(
                                  context,
                                  'Delete expense?',
                                  '$label – ${Fmt.money(e.amount)}',
                                ))
                                  return;
                                final state = context.read<AppState>();
                                await state.expenses.delete(e.id!);
                                state.changed();
                                if (context.mounted) {
                                  snackOk(context, 'Expense deleted');
                                }
                              },
                            ),
                        ],
                      ),
                    ],
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
