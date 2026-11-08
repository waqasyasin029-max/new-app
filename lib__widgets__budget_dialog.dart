import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Asks how much the person can spend this month and saves it as the budget.
/// [monthly] is true for the automatic prompt, which can be skipped.
Future<void> askBudget(BuildContext context, {bool monthly = false}) async {
  final state = context.read<AppState>();
  final month = Fmt.firstOfMonth(DateTime.now());
  final info = await state.incomes.salaryFor(month);
  if (!context.mounted) return;
  final c = TextEditingController(
    text: info.amount > 0 ? Fmt.number(info.amount).replaceAll(',', '') : '',
  );
  final v = await showDialog<double>(
    context: context,
    barrierDismissible: !monthly,
    builder: (ctx) => AlertDialog(
      title: Text('Budget for ${Fmt.month(month)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How much can you spend this month?',
            style: TextStyle(fontSize: 14),
          ),
          if (info.carriedFromMonth != null && info.amount > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Last budget was ${Fmt.money(info.amount)}. Change it or keep it.',
              style: const TextStyle(fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [AmountFormatter()],
            decoration: InputDecoration(
              labelText: tr('Amount (Rs)'),
              prefixText: 'Rs ',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(monthly ? 'Later' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final a = parseAmount(c.text);
            if (a == null) {
              snack(ctx, 'Enter a valid amount.');
              return;
            }
            Navigator.pop(ctx, a);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  c.dispose();
  if (v == null) return;
  await state.incomes.setSalary(month, v);
  state.changed();
  if (context.mounted) snackOk(context, 'Budget saved');
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
