import 'package:flutter/material.dart';

import '../core/i18n.dart' show tr;
import '../core/theme.dart';

/// Bottom bar with four tabs (icon over label). The selected tab is dark
/// (light theme) or white (dark theme), the others are grey. The bar follows
/// the theme. The plus button floats separately on the right.
class FloatingNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTab;
  const FloatingNav({super.key, required this.index, required this.onTab});

  Widget _item(int i, IconData off, IconData on, String label) {
    final selected = index == i;
    final color = selected ? AppColors.ink : AppColors.muted;
    return Expanded(
      child: Semantics(
        label: tr(label),
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTab(i),
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? on : off, size: 26, color: color),
                const SizedBox(height: 3),
                Text(
                  tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 72 + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: AppColors.dark ? AppColors.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.line)),
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, -6),
            color: AppColors.dark
                ? Colors.black.withOpacity(0.35)
                : const Color(0xFF8A8A99).withOpacity(0.16),
          ),
        ],
      ),
      child: Row(
        children: [
          _item(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
          _item(1, Icons.receipt_long_outlined, Icons.receipt_long, 'History'),
          _item(
            2,
            Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet,
            'Accounts',
          ),
          _item(3, Icons.pie_chart_outline, Icons.pie_chart, 'Reports'),
        ],
      ),
    );
  }
}
