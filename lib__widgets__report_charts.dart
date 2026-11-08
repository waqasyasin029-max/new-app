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
      label: tr('Income and expenses for the last 6 months'),
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
                  _legend(AppColors.muted, 'Income', striped: true),
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
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color),
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
                    const SizedBox(width: 6),
                    _spark(),
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
