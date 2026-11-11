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
  late final _c = TextEditingController(
    text: widget.current > 0 ? amountText(widget.current.round()) : '',
  );
  bool _error = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseAmount(_c.text);
    if (v == null || v <= 0) {
      setState(() => _error = true);
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
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
          const SizedBox(height: 10),
          TextField(
            controller: _c,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
              AmountFormatter(),
            ],
            onChanged: (_) {
              if (_error) setState(() => _error = false);
            },
            onSubmitted: (_) => _save(),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: 'Rs ',
              prefixStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
          if (_error)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Enter a valid amount.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 10,
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
                    onPressed: _save,
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
