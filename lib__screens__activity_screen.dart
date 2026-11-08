import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/i18n.dart';
import 'history_screen.dart';
import 'reports_screen.dart';

/// One tab for the records: the monthly summary (reports) and the full
/// list of expenses (history), switched with a segmented control.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => ActivityScreenState();
}

class ActivityScreenState extends State<ActivityScreen> {
  int _tab = 0;

  /// A sideways swipe on this tab first moves between Summary and History.
  /// [step] is +1 toward the next tab in reading direction, -1 toward the
  /// previous. Returns true when it was used here; false at either end, so
  /// the swipe carries on to the neighbouring bottom tab.
  bool swipe(int step) {
    final next = _tab + step;
    if (next < 0 || next > 1) return false;
    HapticFeedback.selectionClick();
    setState(() => _tab = next);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        automaticallyImplyLeading: false,
        title: SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('Summary')),
              ButtonSegment(value: 1, label: Text('History')),
            ],
            selected: {_tab},
            onSelectionChanged: (v) => setState(() => _tab = v.first),
          ),
        ),
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
