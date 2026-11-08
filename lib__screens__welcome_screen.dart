import 'dart:math' as math;

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
            'Your name is shown on Home. It stays on this phone. You can change it freely for 5 minutes; after that, once every 14 days.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _c,
            autofocus: true,
            maxLength: 24,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _done(),
            decoration: InputDecoration(
              labelText: tr('Your name'),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _ok ? _done : null,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

/// The welcome animation: confetti falls, a white badge pops in with a waving
/// hand, then "Welcome", the name and a line fade up. Tap to skip.
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
    duration: const Duration(milliseconds: 3200),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
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

  Widget _fadeUp(double a, double b, Widget child) {
    final t = _p(a, b);
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: child),
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
          final pop = _p(0.0, 0.3, Curves.elasticOut);
          // The hand waves a few times once the badge has landed.
          final wt = ((_c.value - 0.3) / 0.25).clamp(0.0, 1.0);
          final wave = math.sin(wt * math.pi * 4) * 0.35 * (1 - wt);
          final ring = _p(0.0, 0.75, Curves.easeOut);
          final hasName = widget.name.isNotEmpty;
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF5A032), Color(0xFFE8602C), Color(0xFFC2410C)],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _ConfettiPainter(_c.value)),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: (1 - ring) * 0.6,
                              child: Transform.scale(
                                scale: 0.6 + ring * 1.6,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: pop,
                              child: Container(
                                width: 120,
                                height: 120,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x2E000000),
                                      blurRadius: 34,
                                      offset: Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Transform.rotate(
                                  angle: wave,
                                  alignment: const Alignment(0.4, 0.4),
                                  child: const Text(
                                    '👋',
                                    verbatim: true,
                                    style: TextStyle(fontSize: 58),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _fadeUp(
                        0.25,
                        0.45,
                        const Text(
                          'Welcome',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (hasName) ...[
                        const SizedBox(height: 2),
                        _fadeUp(
                          0.35,
                          0.6,
                          Text(
                            widget.name,
                            verbatim: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 44,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _fadeUp(
                        0.5,
                        0.72,
                        const Text(
                          'Your khata is ready. Let\'s begin!',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
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

class _Piece {
  final double x; // 0..1 across the screen
  final double delay; // 0..0.4 of the animation
  final double size;
  final double spin;
  final bool round;
  final Color color;
  const _Piece(this.x, this.delay, this.size, this.spin, this.round, this.color);
}

final List<_Piece> _pieces = () {
  final r = math.Random(7);
  const colors = [
    Color(0xFFFFFFFF),
    Color(0xFFFFE3A3),
    Color(0xFFFFD0B0),
    Color(0xFFFFF3D6),
    Color(0xFFFFB88A),
  ];
  return [
    for (var i = 0; i < 26; i++)
      _Piece(
        0.04 + r.nextDouble() * 0.92,
        r.nextDouble() * 0.35,
        7 + r.nextDouble() * 6,
        4 + r.nextDouble() * 6,
        r.nextBool(),
        colors[r.nextInt(colors.length)],
      ),
  ];
}();

class _ConfettiPainter extends CustomPainter {
  final double t; // 0..1 of the whole animation
  _ConfettiPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _pieces) {
      final f = ((t - p.delay) / 0.65).clamp(0.0, 1.0);
      if (f <= 0 || f >= 1) continue;
      final y = -30 + f * (size.height + 60);
      final x = p.x * size.width + math.sin(f * 6 + p.x * 10) * 14;
      final paint = Paint()
        ..color = p.color.withOpacity(f > 0.85 ? (1 - f) / 0.15 : 1);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(f * p.spin);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
            const Radius.circular(3),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
