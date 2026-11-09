import 'package:flutter/material.dart' hide Text;
import 'package:intl/intl.dart' show DateFormat;

import '../core/app_icons.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

/// What the person picked in [showPdfSheet].
class PdfChoice {
  /// The month (or, for [wholeYear], any day of the year).
  final DateTime month;
  final bool wholeYear;
  const PdfChoice(this.month, this.wholeYear);
}

/// Bottom sheet that asks which month, or which whole year, the PDF is for.
/// Returns null when closed without choosing.
Future<PdfChoice?> showPdfSheet(
  BuildContext context, {
  required DateTime month,
  required int firstYear,
}) {
  return showModalBottomSheet<PdfChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _PdfSheet(initial: month, firstYear: firstYear),
  );
}

class _PdfSheet extends StatefulWidget {
  final DateTime initial;
  final int firstYear;
  const _PdfSheet({required this.initial, required this.firstYear});

  @override
  State<_PdfSheet> createState() => _PdfSheetState();
}

class _PdfSheetState extends State<_PdfSheet> {
  bool _year = false;
  late int _y = widget.initial.year;
  late int _m = widget.initial.month;

  DateTime get _now => DateTime.now();

  void _setYear(int y) => setState(() {
    _y = y;
    // A month that has not come yet falls back to the current month.
    if (_future(_y, _m)) _m = _now.month;
  });

  bool _future(int y, int m) =>
      y > _now.year || (y == _now.year && m > _now.month);

  String _monthShort(int m) {
    final d = DateTime(2000, m, 1);
    return L10n.urdu ? Fmt.month(d).split(' ').first : DateFormat('MMM').format(d);
  }

  String get _summary {
    if (_year) return '${tr('Whole year')}: $_y';
    return Fmt.month(DateTime(_y, _m, 1));
  }

  Widget _tab(String label, bool on, VoidCallback onTap) => Expanded(
    child: Material(
      color: on ? AppColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: on ? FontWeight.w800 : FontWeight.w700,
              color: on ? AppColors.ink : AppColors.muted,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _arrow(IconData icon, VoidCallback? onTap) => Material(
    color: AppColors.fieldFill.withOpacity(onTap == null ? 0.5 : 1),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.line : AppColors.ink,
        ),
      ),
    ),
  );

  Widget _monthChip(int m) {
    final disabled = _future(_y, m);
    final on = !_year && m == _m && !disabled;
    return Material(
      color: on
          ? AppColors.primary
          : disabled
          ? AppColors.bgBottom
          : AppColors.fieldFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: disabled ? null : () => setState(() => _m = m),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Text(
            _monthShort(m),
            verbatim: true,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: on
                  ? Colors.white
                  : disabled
                  ? AppColors.line
                  : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPrev = _y > widget.firstYear;
    final canNext = _y < _now.year;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
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
            padding: const EdgeInsets.fromLTRB(6, 14, 0, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Save report as PDF',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
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
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _tab('One month', !_year, () => setState(() => _year = false)),
                _tab('Whole year', _year, () => setState(() => _year = true)),
              ],
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _arrow(
                    AppIcons.chevronLeft,
                    canPrev ? () => _setYear(_y - 1) : null,
                  ),
                  SizedBox(
                    width: 96,
                    child: Center(
                      child: Text(
                        '$_y',
                        verbatim: true,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  _arrow(
                    AppIcons.chevronRight,
                    canNext ? () => _setYear(_y + 1) : null,
                  ),
                ],
              ),
            ),
          ),
          if (!_year)
            Directionality(
              textDirection: TextDirection.ltr,
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.0,
                children: [for (var m = 1; m <= 12; m++) _monthChip(m)],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                '${tr('Report')}: $_summary',
                verbatim: true,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: () {
                // A month in the future is not allowed: use the current one.
                final m = _future(_y, _m) ? _now.month : _m;
                Navigator.pop(context, PdfChoice(DateTime(_y, m, 1), _year));
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Create PDF',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
