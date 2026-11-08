import 'package:flutter/material.dart';

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
          setState(() => _index = 0);
        } else {
          confirmExit(context);
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: FloatingNav(
          index: _index,
          onTab: (i) => setState(() => _index = i),
          onAdd: () => AddExpenseFlow.start(context),
        ),
      ),
    );
  }
}
