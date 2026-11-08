import 'package:flutter/material.dart' hide Text;

import '../core/app_icons.dart';
import '../core/i18n.dart';
import 'expense_edit_screen.dart';
import 'history_screen.dart';
import 'reports_screen.dart';

/// One tab for the records: the monthly summary (reports) and the full
/// list of expenses (history), switched with a segmented control.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: Text('Summary')),
            ButtonSegment(value: 1, label: Text('History')),
          ],
          selected: {_tab},
          onSelectionChanged: (v) => setState(() => _tab = v.first),
        ),
        actions: [
          if (_tab == 1)
            IconButton(
              tooltip: tr('Add manually'),
              icon: const Icon(AppIcons.addCircle),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseEditScreen()),
              ),
            ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          ReportsScreen(embedded: true),
          HistoryScreen(embedded: true),
        ],
      ),
    );
  }
}
