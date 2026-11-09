import 'package:flutter/material.dart' hide Text;

import '../core/app_icons.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

/// Themed bottom-sheet calendar for choosing a date range (History filter).
Future<DateTimeRange?> showDateRangeSheet(
  BuildContext context, {
  DateTimeRange? initial,
  required DateTime firstDate,
  required DateTime lastDate,
}) => showModalBottomSheet<DateTimeRange>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.surface,
  showDragHandle: false,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => _DateSheet(
    range: true,
    start: initial?.start,
    end: initial?.end,
    firstDate: Fmt.dateOnly(firstDate),
    lastDate: Fmt.dateOnly(lastDate),
  ),
);

/// Same calendar for one day (add / edit expense, transfer).
Future<DateTime?> showDateSheet(
  BuildContext context, {
  required DateTime initial,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final r = await showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _DateSheet(
      range: false,
      start: initial,
      end: initial,
      firstDate: Fmt.dateOnly(firstDate),
      lastDate: Fmt.dateOnly(lastDate),
    ),
  );
  return r?.start;
}

class _DateSheet extends StatefulWidget {
  final bool range;
  final DateTime? start;
  final DateTime? end;
  final DateTime firstDate;
  final DateTime lastDate;
  const _DateSheet({
    required this.range,
    required this.start,
    required this.end,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _month;
  late final DateTime _today = Fmt.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _start = widget.start == null ? null : Fmt.dateOnly(widget.start!);
    _end = widget.end == null ? null : Fmt.dateOnly(widget.end!);
    final basis = _end ?? _start ?? _today;
    _month = Fmt.firstOfMonth(_clamp(basis));
  }

  DateTime _clamp(DateTime d) {
    if (d.isBefore(widget.firstDate)) return widget.firstDate;
    if (d.isAfter(widget.lastDate)) return widget.lastDate;
    return d;
  }

  bool get _canGoBack => _month.isAfter(Fmt.firstOfMonth(widget.firstDate));
  bool get _canGoForward => Fmt.lastOfMonth(_month).isBefore(widget.lastDate);

  void _shift(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by, 1));

  void _tap(DateTime d) {
    setState(() {
      if (!widget.range) {
        _start = d;
        _end = d;
      } else if (_start == null || _end != null) {
        _start = d;
        _end = null;
      } else if (d.isBefore(_start!)) {
        _end = _start;
        _start = d;
      } else {
        _end = d;
      }
    });
  }

  void _preset(DateTime a, DateTime b) {
    setState(() {
      _start = _clamp(a);
      _end = _clamp(b);
      _month = Fmt.firstOfMonth(_end!);
    });
  }

  bool _is(DateTime a, DateTime b) =>
      _start != null && _end != null && _start == a && _end == b;

  void _apply() {
    if (_start == null) return;
    Navigator.pop(context, DateTimeRange(start: _start!, end: _end ?? _start!));
  }

  String _label(DateTime? d) =>
      d == null ? '—' : '${Fmt.dayShort(d)} ${d.year}';

  Widget _pill(String title, DateTime? value, bool active) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.line,
          width: active ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            _label(value),
            verbatim: true,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );

  Widget _chip(String label, DateTime a, DateTime b) {
    final on = _is(_clamp(a), _clamp(b));
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: () => _preset(a, b),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? AppColors.primary : AppColors.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: on ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, bool enabled, VoidCallback onTap) =>
      Material(
        color: AppColors.fieldFill,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, size: 18),
          onPressed: enabled ? onTap : null,
        ),
      );

  Widget _cell(DateTime? d) {
    if (d == null) return const Expanded(child: SizedBox(height: 44));
    final enabled = !d.isBefore(widget.firstDate) && !d.isAfter(widget.lastDate);
    final hasBand = _start != null && _end != null && _start != _end;
    final isS = _start != null && d == _start;
    final isE = _end != null && d == _end;
    final inRange =
        hasBand && d.isAfter(_start!) && d.isBefore(_end!);
    final selected = isS || isE;
    final soft = AppColors.primary.withOpacity(0.14);
    final leftFill = hasBand && (inRange || isE);
    final rightFill = hasBand && (inRange || isS);
    final isToday = d == _today;

    Color textColor = AppColors.ink;
    FontWeight weight = FontWeight.w600;
    if (selected) {
      textColor = Colors.white;
      weight = FontWeight.w800;
    } else if (isToday) {
      textColor = AppColors.primary;
      weight = FontWeight.w800;
    } else if (!enabled) {
      textColor = AppColors.muted.withOpacity(0.45);
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => _tap(d) : null,
        child: SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          color: leftFill ? soft : Colors.transparent,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: rightFill ? soft : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primary : null,
                  border: !selected && isToday
                      ? Border.all(color: AppColors.primary, width: 1.6)
                      : null,
                ),
                child: Text(
                  '${d.day}',
                  verbatim: true,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: weight,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid() {
    // Weeks start on Monday.
    final lead = DateTime(_month.year, _month.month, 1).weekday - 1;
    final days = Fmt.lastOfMonth(_month).day;
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= days; d++) DateTime(_month.year, _month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Row(
            children: [
              for (final n in names)
                Expanded(
                  child: Center(
                    child: Text(
                      n,
                      verbatim: true,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < cells.length; r += 7)
            Row(children: [for (final d in cells.sublist(r, r + 7)) _cell(d)]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fromActive = _start == null || _end != null;
    final monthStart = Fmt.firstOfMonth(_today);
    final lastMonthStart = DateTime(_today.year, _today.month - 1, 1);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 0, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.range ? 'Select dates' : 'Select date',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Material(
                  color: AppColors.fieldFill,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(AppIcons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          if (widget.range)
            Row(
              children: [
                _pill('From', _start, fromActive),
                const SizedBox(width: 10),
                _pill('To', _end, !fromActive),
              ],
            )
          else
            Row(children: [_pill('Date', _start, true)]),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.range
                    ? [
                        _chip('Today', _today, _today),
                        _chip(
                          'Last 7 days',
                          _today.subtract(const Duration(days: 6)),
                          _today,
                        ),
                        _chip('This month', monthStart, _today),
                        _chip(
                          'Last month',
                          lastMonthStart,
                          Fmt.lastOfMonth(lastMonthStart),
                        ),
                      ]
                    : [
                        _chip('Today', _today, _today),
                        _chip(
                          'Yesterday',
                          _today.subtract(const Duration(days: 1)),
                          _today.subtract(const Duration(days: 1)),
                        ),
                      ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navButton(AppIcons.chevronLeft, _canGoBack, () => _shift(-1)),
                Text(
                  Fmt.month(_month),
                  verbatim: true,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _navButton(
                  AppIcons.chevronRight,
                  _canGoForward,
                  () => _shift(1),
                ),
              ],
            ),
          ),
          _grid(),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _start == null ? null : _apply,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
