
import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/app_icons.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../state/app_state.dart';

/// Shown once, after the first setup and before Home: a popup asks for the
/// person's name (it can be skipped), then a short welcome animation plays.
class WelcomeFlowScreen extends StatefulWidget {
  const WelcomeFlowScreen({super.key});

  @override
  State<WelcomeFlowScreen> createState() => _WelcomeFlowScreenState();
}

class _WelcomeFlowScreenState extends State<WelcomeFlowScreen> {
  bool _anim = false;
  String _name = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _askName();
    });
  }

  Future<void> _askName() async {
    final name = await askRequiredName(context);
    if (!mounted) return;
    setState(() {
      _name = name;
      _anim = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: _anim
            ? _WelcomeAnim(
                name: _name,
                onDone: () => context.read<AppState>().finishWelcome(),
              )
            : SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.gradient,
                        ),
                        child: const Icon(
                          AppIcons.check,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'All set up',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// Shows the name popup. The name is required: the sheet cannot be closed
/// without one. Saves it and returns it.
Future<String> askRequiredName(BuildContext context) async {
  final v = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _NameSheet(),
  );
  final name = (v ?? '').trim();
  if (name.isNotEmpty && context.mounted) {
    await context.read<AppState>().setUserName(name);
  }
  return name;
}

class _NameSheet extends StatefulWidget {
  const _NameSheet();

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _ok => _c.text.trim().isNotEmpty;

  /// The biggest size (up to 44) at which the typed name still fits on one
  /// line, so a long name shrinks to fit the popup instead of scrolling.
  double _fit(BuildContext context, double maxW) {
    final text = _c.text;
    if (text.isEmpty || maxW <= 0) return 44;
    final base = DefaultTextStyle.of(context).style.copyWith(
      fontSize: 44,
      fontWeight: FontWeight.w800,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: base),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final w = tp.width;
    tp.dispose();
    if (w <= maxW) return 44;
    return (44 * maxW / w).clamp(20.0, 44.0);
  }

  void _done() {
    if (_ok) Navigator.pop(context, _c.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const Text(
            'What should we call you?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Shown on Home. Stays on this phone.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          // The name is typed big and centred, like the amount, so people
          // enjoy seeing their own name.
          LayoutBuilder(
            builder: (context, box) {
              final target = _fit(context, box.maxWidth - 12);
              // Shrinks (or grows back) smoothly as the name gets longer.
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(end: target),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                builder: (context, size, _) {
                  return TextField(
                controller: _c,
                autofocus: true,
                maxLength: 24,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _done(),
                cursorColor: AppColors.primary,
                style: TextStyle(
                  fontSize: size,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: tr('Your name'),
                  hintStyle: TextStyle(
                    fontSize: 44,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: AppColors.line,
                  ),
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              );
                },
              );
            },
          ),
          Center(
            child: Text(
              'Type your name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _ok ? _done : null,
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Free to change for 5 minutes, then once every 14 days',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

/// The welcome animation (light, clean): an orange badge pops in and its tick
/// draws itself, "Welcome" fades up, the name rises letter by letter, an
/// orange line sweeps under it, then the tagline. Soft dots drift upwards.
/// Tap to skip.
class _WelcomeAnim extends StatefulWidget {
  final String name;
  final VoidCallback onDone;
  const _WelcomeAnim({required this.name, required this.onDone});

  @override
  State<_WelcomeAnim> createState() => _WelcomeAnimState();
}

class _WelcomeAnimState extends State<_WelcomeAnim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3800),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() async {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _finish();
    });
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0..1 progress of [_c] between [a] and [b], eased.
  double _p(double a, double b, [Curve curve = Curves.easeOutCubic]) {
    final t = ((_c.value - a) / (b - a)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  Widget _fadeUp(double a, double b, Widget child, [double dy = 16]) {
    final t = _p(a, b);
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * dy), child: child),
    );
  }

  /// The name, one letter at a time, each rising with a small overshoot.
  Widget _nameLetters() {
    final chars = widget.name.characters.toList();
    final size = chars.length <= 10
        ? 50.0
        : (chars.length <= 14 ? 40.0 : (chars.length <= 18 ? 32.0 : 26.0));
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < chars.length; i++)
          Builder(
            builder: (_) {
              final a = 0.38 + i * 0.025;
              final t = _p(a, a + 0.14, Curves.easeOutBack);
              final o = _p(a, a + 0.07, Curves.easeOut);
              return Opacity(
                opacity: o,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 46),
                  child: Text(
                    chars[i] == ' ' ? '\u00A0' : chars[i],
                    verbatim: true,
                    style: TextStyle(
                      fontSize: size,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final pop = _p(0.0, 0.2, Curves.easeOutBack);
          final tick = _p(0.14, 0.36, Curves.easeOut);
          final ring = _p(0.1, 0.5, Curves.easeOut);
          final sweep = _p(0.62, 0.78);
          final hasName = widget.name.isNotEmpty;
          return Container(
            color: AppColors.dark
                ? const Color(0xFF111216)
                : const Color(0xFFF8F8FA),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _DotsPainter(_c.value)),
                ),
                Align(
                  alignment: const Alignment(0, -0.22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 130,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: (1 - ring) * 0.5,
                              child: Transform.scale(
                                scale: 0.7 + ring * 1.6,
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: pop,
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.gradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x59EE6F2B),
                                      blurRadius: 28,
                                      offset: Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: CustomPaint(painter: _TickPainter(tick)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _fadeUp(
                        0.3,
                        0.46,
                        Text(
                          'Welcome',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      if (hasName) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: _nameLetters(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        width: 120,
                        height: 5,
                        alignment: AlignmentDirectional.centerStart,
                        child: FractionallySizedBox(
                          widthFactor: sweep,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fadeUp(
                        0.7,
                        0.88,
                        Text(
                          'Your khata is ready. Let\'s begin!',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                        14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A white tick that draws itself inside the badge ([t] is 0..1).
class _TickPainter extends CustomPainter {
  final double t;
  _TickPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.29, h * 0.52)
      ..lineTo(w * 0.44, h * 0.67)
      ..lineTo(w * 0.72, h * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.t != t;
}

class _Dot {
  final double x; // 0..1 across the screen
  final double delay; // 0..0.5 of the animation
  final double size;
  final Color color;
  const _Dot(this.x, this.delay, this.size, this.color);
}

const List<_Dot> _dots = [
  _Dot(0.12, 0.00, 8, Color(0xFFF5A032)),
  _Dot(0.28, 0.12, 6, Color(0xFFEE6F2B)),
  _Dot(0.44, 0.24, 9, Color(0xFFFFD0B0)),
  _Dot(0.62, 0.06, 7, Color(0xFFF5A032)),
  _Dot(0.78, 0.18, 9, Color(0xFFEE6F2B)),
  _Dot(0.90, 0.30, 6, Color(0xFFFFD0B0)),
  _Dot(0.20, 0.36, 7, Color(0xFFFFD0B0)),
  _Dot(0.70, 0.42, 6, Color(0xFFF5A032)),
];

/// Soft dots that drift up from the bottom and fade out.
class _DotsPainter extends CustomPainter {
  final double t; // 0..1 of the whole animation
  _DotsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in _dots) {
      final f = ((t - d.delay) / 0.6).clamp(0.0, 1.0);
      if (f <= 0 || f >= 1) continue;
      final y = size.height - 60 - f * 320;
      final a = f < 0.15 ? f / 0.15 : (1 - f);
      canvas.drawCircle(
        Offset(d.x * size.width, y),
        d.size / 2,
        Paint()..color = d.color.withOpacity((a * 0.9).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.t != t;
}
