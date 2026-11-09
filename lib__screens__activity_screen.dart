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

class ActivityScreenState extends State<ActivityScreen>
    with SingleTickerProviderStateMixin {
  int _tab = 0;

  /// Where the two pages are, 0 = Summary fully shown, 1 = History fully
  /// shown. It follows the finger while swiping and glides when released.
  late final AnimationController _c = AnimationController(
    vsync: this,
    value: 0,
  );
  double _w = 390;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _glideTo(int tab) {
    final dist = (_c.value - tab).abs();
    if (dist == 0) return;
    _c.animateTo(
      tab.toDouble(),
      duration: Duration(milliseconds: (380 * dist).round().clamp(160, 380)),
      curve: Curves.easeOutCubic,
    );
  }

  void _select(int next) {
    if (next == _tab) return;
    setState(() => _tab = next);
    _glideTo(next);
  }

  /// The page follows the finger while it moves sideways.
  void dragUpdate(double dx) {
    _c.stop();
    final d = dx / _w * (_rtl ? 1 : -1);
    _c.value = (_c.value + d).clamp(0.0, 1.0);
  }

  /// The finger is lifted. [step] is +1 toward the next page in reading
  /// direction, -1 toward the previous, 0 for "not far enough: go back".
  /// Returns false when the swipe went past either end, so it carries on to
  /// the neighbouring bottom tab.
  bool dragEnd(int step) {
    final next = _tab + step;
    if (step == 0) {
      _glideTo(_tab);
      return true;
    }
    if (next < 0 || next > 1) {
      _glideTo(_tab);
      return false;
    }
    HapticFeedback.selectionClick();
    _select(next);
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
            onSelectionChanged: (v) => _select(v.first),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          _w = box.maxWidth;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final p = _c.value;
              final sign = _rtl ? -1.0 : 1.0;
              return ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Offstage(
                      offstage: p >= 1.0,
                      child: Transform.translate(
                        offset: Offset(-p * _w * sign, 0),
                        child: IgnorePointer(
                          ignoring: _tab != 0,
                          child: const ReportsScreen(embedded: true),
                        ),
                      ),
                    ),
                    Offstage(
                      offstage: p <= 0.0,
                      child: Transform.translate(
                        offset: Offset((1 - p) * _w * sign, 0),
                        child: IgnorePointer(
                          ignoring: _tab != 1,
                          child: const HistoryScreen(embedded: true),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
