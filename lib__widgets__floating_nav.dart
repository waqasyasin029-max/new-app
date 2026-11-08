import 'package:flutter/material.dart';

import '../core/i18n.dart' show tr;
import '../core/theme.dart';
import '../core/app_icons.dart';

/// Bottom bar with a notch around a raised orange "+" button in the middle.
/// Four tabs (icon over label): the selected one is dark (light theme) or
/// white (dark theme), the others are grey. The bar follows the theme.
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
  static const _fabSize = 58.0;
  static const _barHeight = 72.0;
  static const _lift = 34.0; // how far the button rises above the bar

  static const _gap = 92.0; // room for the middle button

  /// Left edge of tab [i] inside a bar [w] wide.
  static double _left(int i, double w) {
    final item = (w - _gap) / 4;
    return i < 2 ? i * item : 2 * item + _gap + (i - 2) * item;
  }

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
      height: _lift + _barHeight + bottom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barHeight + bottom,
            child: CustomPaint(
              painter: _NotchPainter(
                color: bar,
                line: AppColors.line,
                shadow: AppColors.dark ? Colors.black : const Color(0xFF8A8A99),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final item = (box.maxWidth - _gap) / 4;
                    const pillW = 64.0;
                    return Stack(
                      children: [
                        // One soft pill that slides to the selected tab.
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          left: _left(index, box.maxWidth) + (item - pillW) / 2,
                          top: 9,
                          width: pillW,
                          height: 36,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _item(0, AppIcons.home, AppIcons.homeFill, 'Home'),
                            _item(
                              1,
                              AppIcons.wallet,
                              AppIcons.walletFill,
                              'Accounts',
                            ),
                            const SizedBox(width: _gap),
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
                      ],
                    );
                  },
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
                          spreadRadius: 7,
                        ),
                        BoxShadow(
                          color: _fab.withOpacity(0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      AppIcons.add,
                      color: Colors.white,
                      size: 34,
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

/// A bar with rounded top corners and a smooth round bite out of the top
/// edge, where the middle button sits.
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
    const r = 26.0; // top corner radius
    const n = 42.0; // notch radius
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
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
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
