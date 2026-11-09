import 'package:flutter/material.dart';

import '../core/i18n.dart' show tr;
import '../core/theme.dart';
import '../core/app_icons.dart';

/// Floating bar with a notch around a raised orange "+" button in the middle.
/// Four tabs (icon over label) and the "+" share five equal spots. The selected
/// tab has a filled orange icon, the others are grey. The bar follows the theme.
class FloatingNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onAdd;
  const FloatingNav({
    super.key,
    required this.index,
    required this.onTab,
    required this.onAdd,
  });

  static const _fab = AppColors.primary;
  static const _fabSize = 50.0;
  static const _barHeight = 72.0;
  static const _lift = 30.0; // how far the button rises above the bar
  static const _sideGap = 12.0; // space between the bar and the screen edge
  static const _bottomGap = 10.0; // space below the bar

  Widget _item(int i, IconData off, IconData on, String label) {
    final selected = index == i;
    final color = selected ? AppColors.primary : AppColors.muted;
    return Expanded(
      child: Semantics(
        label: tr(label),
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTab(i),
          child: SizedBox(
            height: _barHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Colour fades; the icon makes a small hop when it becomes
                // the selected one.
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: const Duration(milliseconds: 220),
                  builder: (context, c, _) => TweenAnimationBuilder<double>(
                    key: ValueKey(selected),
                    tween: Tween(begin: selected ? 0.8 : 1.0, end: 1.0),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    builder: (context, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Icon(
                      selected ? on : off,
                      size: 28,
                      color: c ?? color,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                  child: Text(
                    tr(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    final bar = AppColors.dark ? AppColors.surface : Colors.white;
    return SizedBox(
      height: _lift + _barHeight + _bottomGap + bottom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _sideGap,
            right: _sideGap,
            bottom: _bottomGap + bottom,
            height: _barHeight,
            child: CustomPaint(
              painter: _NotchPainter(
                color: bar,
                line: AppColors.line,
                shadow: AppColors.dark ? Colors.black : const Color(0xFF8A8A99),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _item(0, AppIcons.home, AppIcons.homeFill, 'Home'),
                    _item(
                      1,
                      AppIcons.wallet,
                      AppIcons.walletFill,
                      'Accounts',
                    ),
                    // The "+" button sits above this spot, same width as a tab.
                    const Expanded(child: SizedBox.shrink()),
                    _item(
                      2,
                      AppIcons.barChart,
                      AppIcons.barChartFill,
                      'Reports',
                    ),
                    _item(
                      3,
                      AppIcons.settings,
                      AppIcons.settingsFill,
                      'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                label: tr('Add expense'),
                button: true,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: _fabSize,
                    height: _fabSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _fab,
                      boxShadow: [
                        BoxShadow(
                          color: _fab.withOpacity(0.18),
                          blurRadius: 0,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: _fab.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: const Icon(
                      AppIcons.add,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded bar with a smooth round bite out of the top edge, where the
/// middle button sits.
class _NotchPainter extends CustomPainter {
  final Color color;
  final Color line;
  final Color shadow;
  const _NotchPainter({
    required this.color,
    required this.line,
    required this.shadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const r = 30.0; // corner radius
    const n = 38.0; // notch radius
    final w = size.width;
    final cx = w / 2;
    final path = Path()
      ..moveTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(cx - n - 16, 0)
      ..cubicTo(cx - n - 3, 0, cx - n + 3, 5, cx - n + 8, 13)
      ..arcToPoint(
        Offset(cx + n - 8, 13),
        radius: const Radius.circular(n),
        clockwise: false,
      )
      ..cubicTo(cx + n - 3, 5, cx + n + 3, 0, cx + n + 16, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, size.height - r)
      ..arcToPoint(Offset(w - r, size.height), radius: const Radius.circular(r))
      ..lineTo(r, size.height)
      ..arcToPoint(Offset(0, size.height - r), radius: const Radius.circular(r))
      ..close();
    canvas.drawShadow(path, shadow.withOpacity(0.5), 12, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = line.withOpacity(0.6),
    );
  }

  @override
  bool shouldRepaint(_NotchPainter old) =>
      old.color != color || old.line != line || old.shadow != shadow;
}
