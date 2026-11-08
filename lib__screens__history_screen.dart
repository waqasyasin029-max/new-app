import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/data_loader.dart';
import 'expense_edit_screen.dart';
import '../core/i18n.dart';
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

  bool get _filtered =>
      _range != null || _categoryId != null || _search.isNotEmpty;

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
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
                  tooltip: tr('Add manually'),
                  icon: const Icon(AppIcons.addCircle),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExpenseEditScreen(),
                    ),
                  ),
                ),
              ],
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              children: [
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
                  return Center(
                    child: Text(
                      _filtered
                          ? 'No transactions match these filters.'
                          : 'No transactions yet.',
                      style: TextStyle(color: AppColors.muted),
                    ),
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
