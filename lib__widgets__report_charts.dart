import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:intl/intl.dart' show DateFormat;

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

/// Income and spending of one month, for the charts.
class MonthPoint {
  final DateTime month;
  final double income;
  final double spent;
  const MonthPoint(this.month, this.income, this.spent);

  double get savedShare =>
      income <= 0 ? 0 : ((income - spent) / income).clamp(0.0, 1.0).toDouble();
}

String _monthShort(DateTime d) =>
    L10n.urdu ? Fmt.month(d).split(' ').first : DateFormat('MMM').format(d);

String _trim(double x) =>
    x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1);

String _compact(double v) {
  if (v >= 1000000) return '${_trim(v / 1000000)}M';
  if (v >= 1000) return '${_trim(v / 1000)}k';
  return v.toStringAsFixed(0);
}

double _niceStep(double raw) {
  if (raw <= 0) return 250;
  final p = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / p;
  final double n = f <= 1
      ? 1.0
      : f <= 2
      ? 2.0
      : f <= 2.5
      ? 2.5
      : f <= 5
      ? 5.0
      : 10.0;
  return n * p;
}

/// Grouped bars per month: striped = income, dark = spending. Dashed grid
/// lines with the scale on the right.
class IncomeExpenseChart extends StatelessWidget {
  final List<MonthPoint> points;
  const IncomeExpenseChart({super.key, required this.points});

  Widget _legend(Color c, String label, {required bool striped}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: striped ? AppColors.muted.withOpacity(0.25) : c,
          borderRadius: BorderRadius.circular(3),
          border: striped ? Border.all(color: AppColors.muted) : null,
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: AppColors.muted)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final last = points.isEmpty ? DateTime.now() : points.last.month;
    return Semantics(
      label: tr('Budget and spending for the last 6 months'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Fmt.month(last),
                verbatim: true,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              Row(
                children: [
                  _legend(AppColors.muted, 'Budget', striped: true),
                  const SizedBox(width: 12),
                  _legend(AppColors.ink, 'Expenses', striped: false),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: CustomPaint(
              painter: _BarsPainter(
                points: points,
                ink: AppColors.ink,
                muted: AppColors.muted,
                grid: AppColors.line,
                labels: [for (final p in points) _monthShort(p.month)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<MonthPoint> points;
  final Color ink;
  final Color muted;
  final Color grid;
  final List<String> labels;
  _BarsPainter({
    required this.points,
    required this.ink,
    required this.muted,
    required this.grid,
    required this.labels,
  });

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    required Color color,
    bool center = false,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center ? Offset(at.dx - tp.width / 2, at.dy) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const axisW = 40.0;
    const bottomH = 24.0;
    const topPad = 6.0;
    final plotW = size.width - axisW;
    final plotH = size.height - bottomH - topPad;
    var maxV = 0.0;
    for (final p in points) {
      maxV = math.max(maxV, math.max(p.income, p.spent));
    }
    if (maxV <= 0) maxV = 1000;
    final step = _niceStep(maxV / 4);
    final count = math.max(1, (maxV / step).ceil());
    final top = step * count;
    double yOf(double v) => topPad + plotH - plotH * (v / top);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= count; i++) {
      final y = yOf(step * i);
      for (var x = 0.0; x < plotW; x += 8) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, plotW), y),
          gridPaint,
        );
      }
      _text(canvas, _compact(step * i), Offset(plotW + 8, y - 7), color: muted);
    }

    final n = points.length;
    if (n == 0) return;
    final gw = plotW / n;
    final barW = math.min(16.0, gw * 0.3);
    const gap = 3.0;
    for (var k = 0; k < n; k++) {
      final cx = gw * (k + 0.5);
      final p = points[k];
      _bar(
        canvas,
        Rect.fromLTWH(
          cx - gap / 2 - barW,
          yOf(p.income),
          barW,
          yOf(0) - yOf(p.income),
        ),
        striped: true,
      );
      _bar(
        canvas,
        Rect.fromLTWH(cx + gap / 2, yOf(p.spent), barW, yOf(0) - yOf(p.spent)),
        striped: false,
      );
      _text(
        canvas,
        labels[k],
        Offset(cx, size.height - bottomH + 8),
        color: k == n - 1 ? ink : muted,
        center: true,
        bold: k == n - 1,
      );
    }
  }

  void _bar(Canvas canvas, Rect r, {required bool striped}) {
    if (r.height < 1) return;
    final rr = RRect.fromRectAndCorners(
      r,
      topLeft: const Radius.circular(4),
      topRight: const Radius.circular(4),
    );
    if (!striped) {
      canvas.drawRRect(rr, Paint()..color = ink);
      return;
    }
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRRect(rr, Paint()..color = muted.withOpacity(0.10));
    final line = Paint()
      ..color = muted.withOpacity(0.55)
      ..strokeWidth = 1;
    for (var x = r.left - r.height; x < r.right; x += 4.5) {
      canvas.drawLine(Offset(x, r.bottom), Offset(x + r.height, r.top), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}

/// A stat card: round icon, label, big coloured number and a tiny bar
/// sketch of the last months. [wide] lays it out in one row.
class MiniStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final List<double> spark;
  final bool dotted;
  final bool wide;
  final String? caption;
  final double valueSize;

  /// Small tiles leave the little bar graph out so the amount gets the room.
  final bool showSpark;
  const MiniStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.spark,
    this.dotted = false,
    this.wide = false,
    this.caption,
    this.valueSize = 24,
    this.showSpark = true,
  });

  Widget _iconBadge() => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.line),
    ),
    child: Icon(icon, size: 20, color: AppColors.ink),
  );

  Widget _valueText() => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      value,
      verbatim: true,
      style: TextStyle(
        fontSize: valueSize,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );

  Widget _spark() => SizedBox(
    width: math.max(1, spark.length) * 8.0,
    height: 30,
    child: CustomPaint(painter: _SparkPainter(spark, color, dotted)),
  );

  @override
  Widget build(BuildContext context) {
    final cap = caption == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              caption!,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          );
    return AppCard(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(16),
      child: wide
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _iconBadge(),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Flexible(child: _valueText()),
                    const Spacer(),
                    _spark(),
                  ],
                ),
                cap,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _iconBadge(),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _valueText()),
                    if (showSpark) const SizedBox(width: 6),
                    if (showSpark) _spark(),
                  ],
                ),
                cap,
              ],
            ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final bool dotted;
  _SparkPainter(this.values, this.color, this.dotted);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    var maxV = 0.0;
    for (final v in values) {
      maxV = math.max(maxV, v);
    }
    for (var i = 0; i < values.length; i++) {
      final isLast = i == values.length - 1;
      final paint = Paint()..color = isLast ? color : color.withOpacity(0.35);
      final h = maxV <= 0
          ? 3.0
          : math.max(3.0, size.height * (values[i] / maxV));
      final x = i * 8.0 + 1;
      if (dotted) {
        for (var y = size.height - 1.5; y > size.height - h; y -= 4) {
          canvas.drawCircle(Offset(x + 1.75, y), 1.4, paint);
        }
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - h, 3.5, h),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => true;
}

/// The chart card on the Summary tab: one bar per day of the month (default),
/// or the last six months. Tap a day to see its amount.
class SpendingChartCard extends StatefulWidget {
  final DateTime month;

  /// Spending per day, keyed 'yyyy-MM-dd'.
  final Map<String, double> daily;

  /// The monthly budget, for the dashed "safe per day" line (0 = no line).
  final double budget;

  /// Average spending per day so far.
  final double perDay;
  final List<MonthPoint> months;
  const SpendingChartCard({
    super.key,
    required this.month,
    required this.daily,
    required this.budget,
    required this.perDay,
    required this.months,
  });

  @override
  State<SpendingChartCard> createState() => _SpendingChartCardState();
}

class _SpendingChartCardState extends State<SpendingChartCard> {
  bool _daily = true;
  int? _picked; // 0-based day of month

  int get _days => Fmt.lastOfMonth(widget.month).day;

  List<double> get _values {
    final out = List<double>.filled(_days, 0);
    widget.daily.forEach((k, v) {
      final d = Fmt.parseKey(k);
      if (d.year == widget.month.year &&
          d.month == widget.month.month &&
          d.day >= 1 &&
          d.day <= _days) {
        out[d.day - 1] = v;
      }
    });
    return out;
  }

  Widget _tab(String label, bool on, VoidCallback onTap) => Expanded(
    child: Material(
      color: on ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: on ? FontWeight.w800 : FontWeight.w700,
              color: on ? AppColors.ink : AppColors.muted,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _stat(String label, String value, String sub, {required bool hot}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: hot
                ? AppColors.primary.withOpacity(0.10)
                : AppColors.fieldFill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              Text(
                value,
                verbatim: true,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: hot ? AppColors.primary : AppColors.ink,
                ),
              ),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  verbatim: true,
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
            ],
          ),
        ),
      );

  Widget _dailyView() {
    final vals = _values;
    var top = 0;
    for (var i = 1; i < vals.length; i++) {
      if (vals[i] > vals[top]) top = i;
    }
    final hasData = vals[top] > 0;
    final safe = widget.budget > 0 ? widget.budget / _days : 0.0;
    final topDate = DateTime(widget.month.year, widget.month.month, top + 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spending by day',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          'Tap a bar to see the amount',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.ltr,
          child: _DailyBars(
            month: widget.month,
            values: vals,
            safe: safe,
            picked: _picked,
            onPick: (i) => setState(() => _picked = i == _picked ? null : i),
          ),
        ),
        if (hasData) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(
                'Highest day',
                Fmt.money(vals[top]),
                Fmt.dayLabel(topDate),
                hot: true,
              ),
              const SizedBox(width: 8),
              _stat(
                'Average per day',
                Fmt.money(widget.perDay),
                '',
                hot: false,
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _tab('Daily', _daily, () => setState(() => _daily = true)),
              _tab('Months', !_daily, () => setState(() => _daily = false)),
            ],
          ),
        ),
        if (_daily) _dailyView() else IncomeExpenseChart(points: widget.months),
      ],
    );
  }
}

class _DailyBars extends StatelessWidget {
  final DateTime month;
  final List<double> values;
  final double safe;
  final int? picked;
  final ValueChanged<int> onPick;
  const _DailyBars({
    required this.month,
    required this.values,
    required this.safe,
    required this.picked,
    required this.onPick,
  });

  static const double _h = 170;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final n = values.length;
        final bw = w / n;
        final p = picked;
        return SizedBox(
          height: _h,
          width: w,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                onPick((d.localPosition.dx / bw).floor().clamp(0, n - 1)),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DailyPainter(
                      values: values,
                      safe: safe,
                      picked: picked,
                      primary: AppColors.primary,
                      ink: AppColors.ink,
                      muted: AppColors.muted,
                      line: AppColors.line,
                      safeLabel:
                          '${tr('Safe per day')} ${Fmt.money(safe.round())}',
                    ),
                  ),
                ),
                if (p != null) _tip(p, w, bw),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tip(int p, double w, double bw) {
    const tw = 104.0;
    final left = (p * bw + bw / 2 - tw / 2).clamp(0.0, w - tw);
    return Positioned(
      left: left,
      top: 0,
      width: tw,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Fmt.dayLabel(DateTime(month.year, month.month, p + 1)),
                verbatim: true,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.surface,
                ),
              ),
              Text(
                Fmt.money(values[p]),
                verbatim: true,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF9A62),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyPainter extends CustomPainter {
  final List<double> values;
  final double safe;
  final int? picked;
  final Color primary;
  final Color ink;
  final Color muted;
  final Color line;
  final String safeLabel;
  _DailyPainter({
    required this.values,
    required this.safe,
    required this.picked,
    required this.primary,
    required this.ink,
    required this.muted,
    required this.line,
    required this.safeLabel,
  });

  void _text(Canvas canvas, String s, Offset at, {bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, right ? Offset(at.dx - tp.width, at.dy) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    const labelH = 20.0;
    const topPad = 46.0; // room for the tip bubble
    final chartH = size.height - labelH - topPad;
    final bw = size.width / n;
    var maxV = safe * 1.15;
    for (final v in values) {
      if (v > maxV) maxV = v;
    }
    if (maxV <= 0) maxV = 1;
    var topIdx = 0;
    for (var i = 1; i < n; i++) {
      if (values[i] > values[topIdx]) topIdx = i;
    }
    final base = topPad + chartH;
    for (var i = 0; i < n; i++) {
      final v = values[i];
      final isTop = v > 0 && i == topIdx;
      final isPicked = picked == i;
      final h = v <= 0 ? 2.0 : math.max(3.0, v / maxV * chartH);
      final paint = Paint()
        ..color = v <= 0
            ? line
            : isPicked
            ? ink
            : isTop
            ? primary
            : primary.withOpacity(0.38);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(i * bw + bw * 0.14, base - h, bw * 0.72, h),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
    }
    if (safe > 0) {
      final y = base - safe / maxV * chartH;
      final dash = Paint()
        ..color = muted.withOpacity(0.7)
        ..strokeWidth = 1.4;
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), dash);
      }
      _text(canvas, safeLabel, Offset(size.width, y - 14), right: true);
    }
    for (final d in const [1, 5, 10, 15, 20, 25, 30]) {
      if (d > n) continue;
      final s = '$d';
      final cx = (d - 1) * bw + bw / 2;
      _text(canvas, s, Offset(cx - (s.length * 3), base + 5));
    }
  }

  @override
  bool shouldRepaint(_DailyPainter o) =>
      o.values != values ||
      o.picked != picked ||
      o.safe != safe ||
      o.primary != primary ||
      o.ink != ink ||
      o.muted != muted ||
      o.line != line ||
      o.safeLabel != safeLabel;
}

/// History: the last 7 days as bars with the amount scale on the left. The
/// picked day (or the highest one) is orange with a bubble. Swipe to the right
/// for older weeks. Tap a bar to show only that day in the list.
class WeekBarsCard extends StatefulWidget {
  /// Spending per day, keyed 'yyyy-MM-dd', covering [weeks] weeks up to today.
  final Map<String, double> daily;
  final int weeks;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onPickDay;

  /// The week shown first, and a callback when it changes, so the screen can
  /// keep the week while the list below reloads.
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  const WeekBarsCard({
    super.key,
    required this.daily,
    required this.weeks,
    required this.selectedDay,
    required this.onPickDay,
    required this.initialPage,
    required this.onPageChanged,
  });

  @override
  State<WeekBarsCard> createState() => _WeekBarsCardState();
}

class _WeekBarsCardState extends State<WeekBarsCard> {
  late int _page = widget.initialPage; // 0 = last 7 days, 1 = week before...
  late final PageController _ctrl = PageController(initialPage: _page);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  DateTime get _today => Fmt.dateOnly(DateTime.now());

  /// Last day of the week shown on [page].
  DateTime _end(int page) {
    final t = _today;
    return DateTime(t.year, t.month, t.day - 7 * page);
  }

  double _amount(DateTime d) => widget.daily[Fmt.key(d)] ?? 0;

  List<DateTime> _days(int page) {
    final end = _end(page);
    return [
      for (var i = 6; i >= 0; i--) DateTime(end.year, end.month, end.day - i),
    ];
  }

  @override
  Widget build(BuildContext context) {
    var maxV = 0.0;
    for (final v in widget.daily.values) {
      if (v > maxV) maxV = v;
    }
    final step = _niceStep(maxV / 3);
    final days = _days(_page);
    var total = 0.0;
    for (final d in days) {
      total += _amount(d);
    }
    final end = days.last;
    final start = days.first;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _page == 0
                    ? const Text(
                        'Last 7 days',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : Text(
                        '${Fmt.dayShort(start)} – ${Fmt.dayShort(end)}',
                        verbatim: true,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  Fmt.money(total),
                  verbatim: true,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _ctrl,
                reverse: true, // swipe to the right for older weeks
                itemCount: widget.weeks,
                onPageChanged: (i) {
                  setState(() => _page = i);
                  widget.onPageChanged(i);
                },
                itemBuilder: (_, page) => _WeekPlot(
                  days: _days(page),
                  values: [for (final d in _days(page)) _amount(d)],
                  step: step,
                  selected: widget.selectedDay,
                  onPick: widget.onPickDay,
                ),
              ),
            ),
          ),
          Text(
            'Swipe right for older weeks. Tap a bar to see that day.',
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _WeekPlot extends StatelessWidget {
  final List<DateTime> days;
  final List<double> values;
  final double step;
  final DateTime? selected;
  final ValueChanged<DateTime> onPick;
  const _WeekPlot({
    required this.days,
    required this.values,
    required this.step,
    required this.selected,
    required this.onPick,
  });

  static const double axisW = 40;

  /// The bar that is orange: the picked day if it is in this week, else the
  /// highest day.
  int? get _hot {
    final sel = selected;
    if (sel != null) {
      for (var i = 0; i < days.length; i++) {
        if (days[i] == Fmt.dateOnly(sel)) return i;
      }
    }
    var top = -1;
    for (var i = 0; i < values.length; i++) {
      if (values[i] > 0 && (top < 0 || values[i] > values[top])) top = i;
    }
    return top < 0 ? null : top;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final plotW = c.maxWidth - axisW;
        final bw = plotW / 7;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final x = d.localPosition.dx - axisW;
            if (x < 0) return;
            onPick(days[(x / bw).floor().clamp(0, 6)]);
          },
          child: CustomPaint(
            size: Size(c.maxWidth, c.maxHeight),
            painter: _WeekPainter(
              days: days,
              values: values,
              step: step,
              hot: _hot,
              primary: AppColors.primary,
              ink: AppColors.ink,
              muted: AppColors.muted,
              grid: AppColors.line,
              bar: AppColors.fieldFill,
              surface: AppColors.surface,
              labels: [for (final d in days) Fmt.weekdayShort(d)],
            ),
          ),
        );
      },
    );
  }
}

class _WeekPainter extends CustomPainter {
  final List<DateTime> days;
  final List<double> values;
  final double step;
  final int? hot;
  final Color primary;
  final Color ink;
  final Color muted;
  final Color grid;
  final Color bar;
  final Color surface;
  final List<String> labels;
  _WeekPainter({
    required this.days,
    required this.values,
    required this.step,
    required this.hot,
    required this.primary,
    required this.ink,
    required this.muted,
    required this.grid,
    required this.bar,
    required this.surface,
    required this.labels,
  });

  TextPainter _tp(String s, double size, FontWeight w, Color c, [double? maxW]) {
    return TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, fontWeight: w, color: c),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxW ?? double.infinity);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const axisW = _WeekPlot.axisW;
    const topPad = 34.0; // room for the bubble
    const labelH = 26.0;
    final plotH = size.height - topPad - labelH;
    final plotW = size.width - axisW;
    final bw = plotW / 7;
    final maxScale = step * 3;
    final base = topPad + plotH;

    // Grid lines and the amount scale on the left.
    for (var k = 0; k <= 3; k++) {
      final y = base - plotH * k / 3;
      final gp = Paint()
        ..color = grid
        ..strokeWidth = 1;
      if (k == 0) {
        canvas.drawLine(Offset(axisW, y), Offset(size.width, y), gp);
      } else {
        for (double x = axisW; x < size.width; x += 8) {
          canvas.drawLine(
            Offset(x, y),
            Offset(math.min(x + 4, size.width), y),
            gp,
          );
        }
      }
      final t = _tp(_compact(step * k), 10.5, FontWeight.w700, muted);
      t.paint(canvas, Offset(axisW - 8 - t.width, y - t.height / 2));
    }

    // Bars.
    for (var i = 0; i < 7; i++) {
      final v = values[i];
      final h = v <= 0 ? 4.0 : math.max(6.0, v / maxScale * plotH);
      final w = bw * 0.6;
      final x = axisW + i * bw + (bw - w) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, base - h, w, h),
        topLeft: const Radius.circular(9),
        topRight: const Radius.circular(9),
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      );
      final isHot = hot == i && v > 0;
      final paint = Paint();
      if (isHot) {
        paint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primary, primary.withOpacity(0.55)],
        ).createShader(rect.outerRect);
      } else {
        paint.color = bar;
      }
      canvas.drawRRect(rect, paint);

      // Day name; bold and dark for the orange bar.
      final lt = _tp(
        labels[i],
        11.5,
        isHot ? FontWeight.w800 : FontWeight.w600,
        isHot ? ink : muted,
        bw,
      );
      lt.paint(
        canvas,
        Offset(axisW + i * bw + (bw - lt.width) / 2, base + 7),
      );

      if (isHot) {
        final cx = axisW + i * bw + bw / 2;
        final tt = _tp(Fmt.number(v), 12, FontWeight.w800, surface);
        final bubbleW = tt.width + 22;
        final bubbleH = 26.0;
        final by = base - h - bubbleH - 8;
        final bx = (cx - bubbleW / 2).clamp(axisW - 8, size.width - bubbleW);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, bubbleW, bubbleH),
            const Radius.circular(13),
          ),
          Paint()..color = ink,
        );
        tt.paint(canvas, Offset(bx + 11, by + (bubbleH - tt.height) / 2));
        canvas.drawCircle(Offset(cx, base - h + 6), 3, Paint()..color = ink);
        canvas.drawCircle(
          Offset(cx, base - h + 6),
          3,
          Paint()
            ..color = surface
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WeekPainter o) =>
      o.values != values ||
      o.hot != hot ||
      o.step != step ||
      o.primary != primary ||
      o.ink != ink ||
      o.muted != muted ||
      o.grid != grid ||
      o.bar != bar ||
      o.surface != surface;
}
