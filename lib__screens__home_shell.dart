import 'package:flutter/material.dart';

import '../widgets/floating_nav.dart';
import 'accounts_screen.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'reports_screen.dart';
import 'voice_entry_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    DashboardScreen(),
    HistoryScreen(),
    AccountsScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: FloatingNav(
        index: _index,
        onTab: (i) => setState(() => _index = i),
        onMic: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VoiceEntryScreen()),
        ),
      ),
    );
  }
}
