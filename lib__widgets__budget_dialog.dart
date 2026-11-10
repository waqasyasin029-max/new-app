import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_icons.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Asks how much the person can spend this month and saves it as the budget.
/// [monthly] is true for the automatic prompt, which can be skipped.
Future<void> askBudget(
  BuildContext context, {
  bool monthly = false,
  DateTime? forMonth,
}) async {
  final state = context.read<AppState>();
  final month = Fmt.firstOfMonth(forMonth ?? DateTime.now());
  final info = await state.incomes.salaryFor(month);
  if (!context.mounted) return;
  final v = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: !monthly,
    enableDrag: !monthly,
    backgroundColor: AppColors.surface,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _BudgetSheet(
      month: month,
      current: info.amount,
      carried: info.carriedFromMonth != null && info.amount > 0,
      monthly: monthly,
    ),
  );
  if (v == null) return;
  await state.incomes.setSalary(month, v);
  state.changed();
  if (context.mounted) snackOk(context, 'Budget saved');
}

class _BudgetSheet extends StatefulWidget {
  final DateTime month;
  final double current;
  final bool carried;
  final bool monthly;
  const _BudgetSheet({
    required this.month,
    required this.current,
    required this.carried,
    required this.monthly,
  });

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late String _digits =
      widget.current > 0 ? widget.current.round().toString() : '';
  bool _error = false;

  int get _value => int.tryParse(_digits) ?? 0;

  void _press(String k) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = false;
      if (k == 'back') {
        if (_digits.isNotEmpty) {
          _digits = _digits.substring(0, _digits.length - 1);
        }
      } else {
        var next = _digits + k;
        next = next.replaceFirst(RegExp(r'^0+'), '');
        if (next.length <= 9) _digits = next;
      }
    });
  }

  Widget _key(String k) {
    final isBack = k == 'back';
    return Material(
      color: AppColors.fieldFill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _press(k),
        onLongPress: isBack
            ? () => setState(() {
                _digits = '';
              })
            : null,
        child: SizedBox(
          height: 52,
          child: Center(
            child: isBack
                ? Icon(AppIcons.backspace, color: AppColors.ink, size: 22)
                : Text(
                    k,
                    verbatim: true,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, {VoidCallback? onTap, bool dark = false}) =>
      Material(
        color: dark ? AppColors.navy : AppColors.fieldFill,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final days = Fmt.lastOfMonth(widget.month).day;
    final perDay = _value / days;
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '000', '0', 'back'];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.savings,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget for ${Fmt.month(widget.month)}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      widget.carried
                          ? 'Last budget was ${Fmt.money(widget.current)}. Change it or keep it.'
                          : 'How much can you spend this month?',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Rs ',
                  verbatim: true,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  _digits.isEmpty ? '0' : Fmt.number(_value),
                  verbatim: true,
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: _digits.isEmpty
                        ? AppColors.muted
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.current > 0)
                _chip(
                  'Same as last: ${Fmt.money(widget.current)}',
                  onTap: () => setState(() {
                    _error = false;
                    _digits = widget.current.round().toString();
                  }),
                ),
              if (_value > 0)
                _chip('${Fmt.money(perDay)} per day', dark: true),
            ],
          ),
          if (_error)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Enter a valid amount.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.3,
            children: [for (final k in keys) _key(k)],
          ),
          const SizedBox(height: 14),
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
                    child: Text(
                      widget.monthly ? 'Later' : 'Cancel',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
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
                    onPressed: () {
                      if (_value <= 0) {
                        setState(() => _error = true);
                        return;
                      }
                      Navigator.pop(context, _value.toDouble());
                    },
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

/// Once per month, when this month has no budget of its own yet, asks for it.
Future<void> maybeAskMonthlyBudget(BuildContext context) async {
  final state = context.read<AppState>();
  final month = Fmt.firstOfMonth(DateTime.now());
  final key = Fmt.monthKey(month);
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('budget_asked') == key) return;
  final info = await state.incomes.salaryFor(month);
  if (info.carriedFromMonth == null && info.amount > 0) return;
  await prefs.setString('budget_asked', key);
  if (!context.mounted) return;
  await askBudget(context, monthly: true);
}
