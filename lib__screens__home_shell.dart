import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/i18n.dart' show tr;
import '../core/theme.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/budget_dialog.dart';
import '../widgets/common.dart' show confirmExit;
import '../widgets/fade_slide_page.dart';
import '../widgets/floating_nav.dart';
import 'add_expense_flow.dart';
import 'accounts_screen.dart';
import 'dashboard_screen.dart';
import 'welcome_screen.dart' show askRequiredName;
import 'activity_screen.dart';
import 'settings_screen.dart';
import '../core/app_icons.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Which side the new page slides in from (1 = right, -1 = left): the side
  /// its tab is on. Urdu mirrors the bar, so it flips there.
  int _dir = 1;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  void _go(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _dir = (i > _index ? 1 : -1) * (_rtl ? -1 : 1);
      _index = i;
    });
  }

  double _drag = 0;

  /// Swiping the page sideways moves to the neighbouring tab.
  void _swipeEnd(DragEndDetails d) {
    final dx = _drag;
    final v = d.primaryVelocity ?? 0;
    _drag = 0;
    final far = dx.abs() > 70;
    final fast = v.abs() > 500;
    final activity = _index == 2 ? _activityKey.currentState : null;
    if (!far && !fast) {
      activity?.dragEnd(0); // not far enough: Summary / History glides back
      return;
    }
    final toLeft = (far ? dx : v) < 0;
    var step = toLeft ? 1 : -1;
    if (_rtl) step = -step;
    // On the Activity tab the swipe first switches Summary <-> History.
    if (activity != null && activity.dragEnd(step)) return;
    final next = _index + step;
    if (next >= 0 && next < _pages.length) _go(next);
  }

  @override
  void initState() {
    super.initState();
    // Once a month, ask what this month's budget is.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // People who installed before names existed are asked once.
      if (context.read<AppState>().userName.isEmpty) {
        await askRequiredName(context);
      }
      if (mounted) maybeAskMonthlyBudget(context);
    });
  }

  final _activityKey = GlobalKey<ActivityScreenState>();

  late final List<Widget> _pages = <Widget>[
    const DashboardScreen(),
    const AccountsScreen(),
    ActivityScreen(key: _activityKey),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Back from any other tab returns to Home first; on Home it asks before
    // closing the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index != 0) {
          _go(0);
        } else {
          confirmExit(context);
        }
      },
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => _drag = 0,
          onHorizontalDragUpdate: (d) {
            _drag += d.delta.dx;
            // On the Activity tab the page follows the finger.
            if (_index == 2) _activityKey.currentState?.dragUpdate(d.delta.dx);
          },
          onHorizontalDragEnd: _swipeEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < _pages.length; i++)
                FadeSlidePage(active: i == _index, dir: _dir, child: _pages[i]),
            ],
          ),
        ),
        bottomNavigationBar: FloatingNav(
          index: _index,
          onTab: _go,
          onAdd: () => AddExpenseFlow.start(context),
        ),
      ),
    );
  }
}
