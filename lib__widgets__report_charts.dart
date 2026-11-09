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

/// The last months as capsule bars (spending). Tap one for its budget and
/// spending; without a tap the highest month is orange.
class IncomeExpenseChart extends StatefulWidget {
  final List<MonthPoint> points;
  const IncomeExpenseChart({super.key, required this.points});

  @override
  State<IncomeExpenseChart> createState() => _IncomeExpenseChartState();
}

class _IncomeExpenseChartState extends State<IncomeExpenseChart> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    final values = [for (final p in pts) p.spent];
    var top = -1;
    var maxV = 0.0;
    for (var i = 0; i < values.length; i++) {
      if (values[i] > maxV) maxV = values[i];
      if (values[i] > 0 && (top < 0 || values[i] > values[top])) top = i;
    }
    final hot = (_picked != null && _picked! < pts.length) ? _picked : (top < 0 ? null : top);
    return Semantics(
      label: tr('Budget and spending for the last 6 months'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 6 months',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              height: 210,
              child: LayoutBuilder(
                builder: (context, c) {
                  final n = pts.length;
                  final bw = n == 0 ? 1.0 : (c.maxWidth - 40) / n;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) {
                      final x = d.localPosition.dx - 40;
                      if (x < 0 || n == 0) return;
                      final i = (x / bw).floor().clamp(0, n - 1);
                      setState(() => _picked = i == _picked ? null : i);
                    },
                    child: CustomPaint(
                      size: Size(c.maxWidth, c.maxHeight),
                      painter: _DailyPainter(
                        values: values,
                        labels: [for (final p in pts) _monthShort(p.month)],
                        step: _niceStep(maxV / 3),
                        hot: hot,
                        hotTitle: hot == null ? '' : Fmt.month(pts[hot].month),
                        hotLines: hot == null
                            ? const []
                            : [
                                '${tr('Budget')} : ${Fmt.money(pts[hot].income)}',
                                '${tr('Spent')} : ${Fmt.money(pts[hot].spent)}',
                              ],
                        primary: AppColors.primary,
                        ink: AppColors.ink,
                        muted: AppColors.muted,
                        grid: AppColors.line,
                        track: AppColors.fieldFill.withOpacity(0.7),
                        off: AppColors.line,
                        surface: AppColors.surface,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Tap a bar to see the amount.',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
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

  /// Average spending per day so far.
  final double perDay;
  final List<MonthPoint> months;
  const SpendingChartCard({
    super.key,
    required this.month,
    required this.daily,
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

  Widget _flatStat(String label, String value, String sub) => Expanded(
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
        const SizedBox(height: 2),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              value,
              verbatim: true,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            if (sub.isNotEmpty)
              Text(
                '  · $sub',
                verbatim: true,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _dailyView() {
    final vals = _values;
    var top = 0;
    for (var i = 1; i < vals.length; i++) {
      if (vals[i] > vals[top]) top = i;
    }
    final hasData = vals[top] > 0;
    var maxV = 0.0;
    for (final v in vals) {
      if (v > maxV) maxV = v;
    }
    final now = DateTime.now();
    final isCurrent =
        widget.month.year == now.year && widget.month.month == now.month;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Spending by day',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                Fmt.month(widget.month),
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
          child: _DailyPages(
            month: widget.month,
            values: vals,
            step: _niceStep(maxV / 3),
            picked: _picked,
            startPage: isCurrent ? (now.day - 1) ~/ 10 : top ~/ 10,
            onPick: (i) => setState(() => _picked = i == _picked ? null : i),
          ),
        ),
        if (hasData) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                _flatStat(
                  'Highest day',
                  Fmt.money(vals[top]),
                  Fmt.dayShort(
                    DateTime(widget.month.year, widget.month.month, top + 1),
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: AppColors.line,
                ),
                _flatStat('Average per day', Fmt.money(widget.perDay), ''),
              ],
            ),
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

/// The month in three pages of about ten days each. Swipe for the next ten.
class _DailyPages extends StatefulWidget {
  final DateTime month;
  final List<double> values;
  final double step;
  final int? picked; // 0-based day of month
  final int startPage;
  final ValueChanged<int> onPick;
  const _DailyPages({
    required this.month,
    required this.values,
    required this.step,
    required this.picked,
    required this.startPage,
    required this.onPick,
  });

  @override
  State<_DailyPages> createState() => _DailyPagesState();
}

class _DailyPagesState extends State<_DailyPages> {
  static const _pages = 3;
  late int _page = widget.startPage.clamp(0, _pages - 1);
  late final PageController _ctrl = PageController(initialPage: _page);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int _from(int page) => page * 10;
  int _to(int page) => page == _pages - 1 ? widget.values.length : page * 10 + 10;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: _pages,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, page) => _DailyPage(
              month: widget.month,
              from: _from(page),
              values: widget.values.sublist(_from(page), _to(page)),
              step: widget.step,
              picked: widget.picked,
              onPick: widget.onPick,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _pages; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.primary : AppColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Swipe for the next days. Tap a bar to see the amount.',
          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _DailyPage extends StatelessWidget {
  final DateTime month;
  final int from; // 0-based day of month of the first bar
  final List<double> values;
  final double step;
  final int? picked;
  final ValueChanged<int> onPick;
  const _DailyPage({
    required this.month,
    required this.from,
    required this.values,
    required this.step,
    required this.picked,
    required this.onPick,
  });

  static const double axisW = 40;

  /// The orange bar (index in this page): the picked day if it is here, else
  /// the highest day of this page.
  int? get _hot {
    final p = picked;
    if (p != null && p >= from && p < from + values.length) return p - from;
    var top = -1;
    for (var i = 0; i < values.length; i++) {
      if (values[i] > 0 && (top < 0 || values[i] > values[top])) top = i;
    }
    return top < 0 ? null : top;
  }

  @override
  Widget build(BuildContext context) {
    final hot = _hot;
    return LayoutBuilder(
      builder: (context, c) {
        final bw = (c.maxWidth - axisW) / values.length;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final x = d.localPosition.dx - axisW;
            if (x < 0) return;
            onPick(from + (x / bw).floor().clamp(0, values.length - 1));
          },
          child: CustomPaint(
            size: Size(c.maxWidth, c.maxHeight),
            painter: _DailyPainter(
              values: values,
              labels: [for (var i = 0; i < values.length; i++) '${from + 1 + i}'],
              step: step,
              hot: hot,
              hotTitle: hot == null
                  ? ''
                  : Fmt.dayLabel(DateTime(month.year, month.month, from + hot + 1)),
              hotLines: hot == null
                  ? const []
                  : ['${tr('Spent')} : ${Fmt.money(values[hot])}'],
              primary: AppColors.primary,
              ink: AppColors.ink,
              muted: AppColors.muted,
              grid: AppColors.line,
              track: AppColors.fieldFill.withOpacity(0.7),
              off: AppColors.line,
              surface: AppColors.surface,
            ),
          ),
        );
      },
    );
  }
}

class _DailyPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double step;
  final int? hot;
  final String hotTitle;
  final List<String> hotLines;
  final Color primary;
  final Color ink;
  final Color muted;
  final Color grid;
  final Color track;
  final Color off;
  final Color surface;
  _DailyPainter({
    required this.values,
    required this.labels,
    required this.step,
    required this.hot,
    required this.hotTitle,
    required this.hotLines,
    required this.primary,
    required this.ink,
    required this.muted,
    required this.grid,
    required this.track,
    required this.off,
    required this.surface,
  });

  TextPainter _tp(String s, double size, FontWeight w, Color c) {
    return TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, fontWeight: w, color: c),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    const axisW = _DailyPage.axisW;
    const topPad = 70.0; // room for the tooltip card
    const labelH = 24.0;
    final n = values.length;
    final plotH = size.height - topPad - labelH;
    final bw = (size.width - axisW) / n;
    final maxScale = step * 3;
    final base = topPad + plotH;

    // Amount scale on the left; dashed line at zero.
    for (var k = 0; k <= 3; k++) {
      final y = base - plotH * k / 3;
      final t = _tp(_compact(step * k), 10.5, FontWeight.w700, muted);
      t.paint(canvas, Offset(axisW - 8 - t.width, y - t.height / 2));
    }
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (double x = axisW; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, base),
        Offset(math.min(x + 4, size.width), base),
        gp,
      );
    }

    for (var i = 0; i < n; i++) {
      final v = values[i];
      final w = math.min(bw * 0.62, 30.0);
      final cx = axisW + i * bw + bw / 2;
      final x = cx - w / 2;
      // Pale track: the full height this bar could reach.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, topPad, w, plotH),
          Radius.circular(w / 2),
        ),
        Paint()..color = track,
      );
      final h = v <= 0 ? w * 0.7 : math.max(w, v / maxScale * plotH);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, base - h, w, h),
        Radius.circular(w / 2),
      );
      final isHot = hot == i && v > 0;
      final paint = Paint();
      if (v <= 0) {
        paint.color = off;
      } else if (isHot) {
        paint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primary, primary.withOpacity(0.65)],
        ).createShader(rect.outerRect);
      } else {
        paint.color = primary.withOpacity(0.55);
      }
      canvas.drawRRect(rect, paint);

      // Day number under the bar; the orange bar's one is bold and dark.
      final lt = _tp(
        labels[i],
        11,
        hot == i ? FontWeight.w800 : FontWeight.w600,
        hot == i ? ink : muted,
      );
      lt.paint(canvas, Offset(cx - lt.width / 2, base + 6));

      if (isHot) {
        final d = _tp(hotTitle, 11, FontWeight.w700, muted);
        final ls = [
          for (final l in hotLines) _tp(l, 13, FontWeight.w800, ink),
        ];
        var cardW = d.width;
        for (final l in ls) {
          cardW = math.max(cardW, l.width);
        }
        cardW += 24;
        final cardH = 14.0 + 16 + ls.length * 18;
        var by = base - h - cardH - 8;
        if (by < 0) by = 0;
        final bx = (cx - cardW / 2)
            .clamp(axisW - 8, size.width - cardW)
            .toDouble();
        final card = RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, cardW, cardH),
          const Radius.circular(10),
        );
        canvas.drawShadow(Path()..addRRect(card), Colors.black, 6, true);
        canvas.drawRRect(card, Paint()..color = surface);
        canvas.drawRRect(
          card,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = grid,
        );
        d.paint(canvas, Offset(bx + (cardW - d.width) / 2, by + 7));
        for (var k = 0; k < ls.length; k++) {
          ls[k].paint(
            canvas,
            Offset(bx + (cardW - ls[k].width) / 2, by + 7 + 16 + k * 18),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DailyPainter o) =>
      o.values != values ||
      o.hot != hot ||
      o.hotTitle != hotTitle ||
      o.labels != labels ||
      o.hotLines != hotLines ||
      o.step != step ||
      o.primary != primary ||
      o.ink != ink ||
      o.muted != muted ||
      o.grid != grid ||
      o.track != track ||
      o.off != off ||
      o.surface != surface;
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
              height: 210,
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
    final hot = _hot;
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
            painter: _DailyPainter(
              values: values,
              labels: [for (final d in days) Fmt.weekdayShort(d)],
              step: step,
              hot: hot,
              hotTitle: hot == null ? '' : Fmt.dayLabel(days[hot]),
              hotLines: hot == null
                  ? const []
                  : ['${tr('Spent')} : ${Fmt.money(values[hot])}'],
              primary: AppColors.primary,
              ink: AppColors.ink,
              muted: AppColors.muted,
              grid: AppColors.line,
              track: AppColors.fieldFill.withOpacity(0.7),
              off: AppColors.line,
              surface: AppColors.surface,
            ),
          ),
        );
      },
    );
  }
}
