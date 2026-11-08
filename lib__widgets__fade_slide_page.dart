import 'package:flutter/material.dart';

/// One page of a set (bottom tabs, or Summary / History). All pages stay alive (so scroll position and typed text
/// are kept); the page being left fades out while the new one fades in and
/// slides a little from the side [dir] points to (1 = right, -1 = left).
class FadeSlidePage extends StatefulWidget {
  final bool active;
  final int dir;
  final Widget child;
  const FadeSlidePage({
    super.key,
    required this.active,
    required this.dir,
    required this.child,
  });

  @override
  State<FadeSlidePage> createState() => _FadeSlidePageState();
}

class _FadeSlidePageState extends State<FadeSlidePage>
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
  void didUpdateWidget(FadeSlidePage old) {
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
