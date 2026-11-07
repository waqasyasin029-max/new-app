import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/i18n.dart' show tr;

/// Floating pill navigation that follows the theme: dark pill in dark mode,
/// white pill in light mode (selected tab = contrasting circle) with a gold write button in the middle.
class FloatingNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onMic;
  const FloatingNav({
    super.key,
    required this.index,
    required this.onTab,
    required this.onMic,
  });

  Widget _item(int i, IconData off, IconData on, String label) {
    final selected = index == i;
    return Semantics(
      label: tr(label),
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTab(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? (AppColors.dark ? Colors.white : AppColors.navy)
                : Colors.transparent,
          ),
          child: Icon(
            selected ? on : off,
            size: 24,
            color: selected
                ? (AppColors.dark ? AppColors.navy : Colors.white)
                : (AppColors.dark ? Colors.white70 : AppColors.muted),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.dark ? AppColors.navy : Colors.white,
            borderRadius: BorderRadius.circular(34),
            border: AppColors.dark ? null : Border.all(color: AppColors.line),
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, 6),
                color: AppColors.dark
                    ? Colors.black26
                    : const Color(0x1A000000),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _item(0, Icons.home_outlined, Icons.home, 'Home'),
              _item(
                1,
                Icons.receipt_long_outlined,
                Icons.receipt_long,
                'History',
              ),
              Semantics(
                label: 'Add or ask',
                button: true,
                child: GestureDetector(
                  onTap: onMic,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE8602C), Color(0xFFF5A032)],
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              _item(
                2,
                Icons.account_balance_wallet_outlined,
                Icons.account_balance_wallet,
                'Accounts',
              ),
              _item(3, Icons.pie_chart_outline, Icons.pie_chart, 'Reports'),
            ],
          ),
        ),
      ),
    );
  }
}
