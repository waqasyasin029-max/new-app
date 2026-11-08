import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/i18n.dart' show tr;
import '../core/theme.dart';
import '../widgets/budget_dialog.dart';
import '../widgets/common.dart' show confirmExit;
import '../widgets/floating_nav.dart';
import 'add_expense_flow.dart';
import 'accounts_screen.dart';
import 'dashboard_screen.dart';
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

  /// Which way the last tab change went (1 = to the right), so the new
  /// page slides in from that side.
  int _dir = 1;

  void _go(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _dir = i > _index ? 1 : -1;
      _index = i;
    });
  }

  @override
  void initState() {
    super.initState();
    // Once a month, ask what this month's budget is.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeAskMonthlyBudget(context);
    });
  }

  static const _pages = <Widget>[
    DashboardScreen(),
    AccountsScreen(),
    ActivityScreen(),
    SettingsScreen(),
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
        body: Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < _pages.length; i++)
              _TabPage(active: i == _index, dir: _dir, child: _pages[i]),
          ],
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

/// One tab's page. All pages stay alive (so scroll position and typed text
/// are kept); the page being left fades out while the new one fades in and
/// slides a little from the side the tab is on.
class _TabPage extends StatefulWidget {
  final bool active;
  final int dir;
  final Widget child;
  const _TabPage({
    required this.active,
    required this.dir,
    required this.child,
  });

  @override
  State<_TabPage> createState() => _TabPageState();
}

class _TabPageState extends State<_TabPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 160),
    value: widget.active ? 1 : 0,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(_TabPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _c.forward();
    } else if (!widget.active && old.active) {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        return Offstage(
          offstage: _c.isDismissed,
          child: IgnorePointer(
            ignoring: !widget.active,
            child: FadeTransition(
              opacity: _fade,
              child: Transform.translate(
                offset: Offset(
                  widget.active ? (1 - _fade.value) * 28 * widget.dir : 0,
                  0,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
