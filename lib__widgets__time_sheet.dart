import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/app_icons.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

/// Bottom sheet with three wheels (hour, minute, AM/PM) for the reminder time.
/// Returns null when closed without saving.
Future<TimeOfDay?> showTimeSheet(
  BuildContext context, {
  required TimeOfDay initial,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _TimeSheet(initial: initial),
  );
}

class _TimeSheet extends StatefulWidget {
  final TimeOfDay initial;
  const _TimeSheet({required this.initial});

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  static const double _row = 44;
  static const double _height = 168;

  late int _h12 = widget.initial.hourOfPeriod == 0
      ? 12
      : widget.initial.hourOfPeriod; // 1..12
  late int _min = widget.initial.minute;
  late bool _pm = widget.initial.period == DayPeriod.pm;

  late final FixedExtentScrollController _hCtrl = FixedExtentScrollController(
    initialItem: _h12 - 1,
  );
  late final FixedExtentScrollController _mCtrl = FixedExtentScrollController(
    initialItem: _min,
  );
  late final FixedExtentScrollController _pCtrl = FixedExtentScrollController(
    initialItem: _pm ? 1 : 0,
  );

  @override
  void dispose() {
    _hCtrl.dispose();
    _mCtrl.dispose();
    _pCtrl.dispose();
    super.dispose();
  }

  TimeOfDay get _time =>
      TimeOfDay(hour: (_h12 % 12) + (_pm ? 12 : 0), minute: _min);

  String get _mm => _min.toString().padLeft(2, '0');

  /// Time left until this reminder next rings.
  String get _until {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    final mins = at.difference(now).inMinutes + 1;
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '$m ${tr('min')}';
    if (m == 0) return '$h ${tr('hr')}';
    return '$h ${tr('hr')} $m ${tr('min')}';
  }

  void _tick() => HapticFeedback.selectionClick();

  Widget _wheel({
    required FixedExtentScrollController ctrl,
    required double width,
    required List<String> items,
    required bool loop,
    required int selected,
    required ValueChanged<int> onChanged,
  }) {
    Widget item(int i) {
      var d = (i - selected).abs();
      if (loop && items.length - d < d) d = items.length - d;
      return Center(
        child: Text(
          items[i],
          verbatim: true,
          style: TextStyle(
            fontSize: d == 0 ? 30 : (d == 1 ? 20 : 15),
            fontWeight: d == 0 ? FontWeight.w800 : FontWeight.w600,
            color: d == 0
                ? AppColors.ink
                : (d == 1 ? AppColors.muted : AppColors.line),
          ),
        ),
      );
    }

    final kids = [for (var i = 0; i < items.length; i++) item(i)];
    return SizedBox(
      width: width,
      child: ListWheelScrollView.useDelegate(
        controller: ctrl,
        itemExtent: _row,
        diameterRatio: 2.4,
        perspective: 0.002,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) {
          _tick();
          onChanged(loop ? i % items.length : i);
        },
        childDelegate: loop
            ? ListWheelChildLoopingListDelegate(children: kids)
            : ListWheelChildListDelegate(children: kids),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hours = [for (var i = 1; i <= 12; i++) '$i'];
    final mins = [for (var i = 0; i < 60; i++) i.toString().padLeft(2, '0')];
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
            padding: const EdgeInsets.fromLTRB(6, 14, 0, 2),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Reminder time',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Text(
              'Pick the time you usually finish your day.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily at',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted,
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$_h12:$_mm',
                              verbatim: true,
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _pm ? 'PM' : 'AM',
                              verbatim: true,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Next reminder',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        _until,
                        verbatim: true,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: _height,
            decoration: BoxDecoration(
              color: AppColors.fieldFill.withOpacity(0.5),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 46,
                      margin: const EdgeInsets.symmetric(horizontal: 26),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.35),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _wheel(
                          ctrl: _hCtrl,
                          width: 70,
                          items: hours,
                          loop: true,
                          selected: _h12 - 1,
                          onChanged: (i) => setState(() => _h12 = i + 1),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            ':',
                            verbatim: true,
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _wheel(
                          ctrl: _mCtrl,
                          width: 70,
                          items: mins,
                          loop: true,
                          selected: _min,
                          onChanged: (i) => setState(() => _min = i),
                        ),
                        _wheel(
                          ctrl: _pCtrl,
                          width: 64,
                          items: const ['AM', 'PM'],
                          loop: false,
                          selected: _pm ? 1 : 0,
                          onChanged: (i) => setState(() => _pm = i == 1),
                        ),
                      ],
                    ),
                    // Soft fade at the top and bottom of the wheels.
                    IgnorePointer(
                      child: Column(
                        children: [
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.surface,
                                  AppColors.surface.withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppColors.surface.withOpacity(0),
                                  AppColors.surface,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.fieldFill,
                      foregroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 14,
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _time),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
