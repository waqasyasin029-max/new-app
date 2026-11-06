import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/data_loader.dart';
import 'expense_edit_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTimeRange? _range;
  int? _categoryId;
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
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Add manually',
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpenseEditScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search description',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _range == null
                              ? 'Any date'
                              : '${Fmt.dayShort(_range!.start)} – ${Fmt.dayShort(_range!.end)}',
                          overflow: TextOverflow.ellipsis,
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
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _range = null;
                        _categoryId = null;
                        _search = '';
                      }),
                      icon: const Icon(Icons.clear),
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
                    ),
                  );
                }
                final total = list.fold<double>(0, (a, e) => a + e.amount);
                final byDay = <String, List<Expense>>{};
                for (final e in list) {
                  byDay.putIfAbsent(Fmt.key(e.date), () => []).add(e);
                }
                final days = byDay.keys.toList(); // already newest first
                return ListView(
                  padding: const EdgeInsets.only(bottom: 110),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        '${list.length} transactions • ${Fmt.money(total)}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    for (final day in days) ...[
                      Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              Fmt.date(Fmt.parseKey(day)),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
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
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                            if (!await confirmDialog(
                              context,
                              'Delete expense?',
                              '${e.description.isEmpty ? e.categoryName : e.description} – ${Fmt.money(e.amount)}',
                            ))
                              return;
                            final state = context.read<AppState>();
                            await state.expenses.delete(e.id!);
                            state.changed();
                          },
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
