import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/account_style.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Add a new account or rename / retype an existing one.
Future<void> showAccountDialog(
  BuildContext context, {
  Account? existing,
}) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final balance = TextEditingController();
  var type = existing?.type ?? 'wallet';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(existing == null ? 'Add account' : 'Edit account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name (e.g. HBL, SadaPay)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final t in AccountStyle.types)
                  DropdownMenuItem(
                    value: t,
                    child: Text(AccountStyle.label(t)),
                  ),
              ],
              onChanged: (v) => setD(() => type = v ?? type),
            ),
            if (existing == null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: balance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Money in it right now (Rs)',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
            onPressed: () {
              if (name.text.trim().isEmpty) {
                snack(ctx, 'Enter a name.');
                return;
              }
              if (existing == null &&
                  balance.text.trim().isNotEmpty &&
                  double.tryParse(balance.text.trim().replaceAll(',', '')) ==
                      null) {
                snack(ctx, 'Enter a valid balance.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  final n = name.text.trim();
  final b = double.tryParse(balance.text.trim().replaceAll(',', '')) ?? 0;
  name.dispose();
  balance.dispose();
  if (ok != true || !context.mounted) return;
  final state = context.read<AppState>();
  try {
    if (existing == null) {
      await state.accountRepo.insert(n, type, b);
    } else {
      await state.accountRepo.update(existing.id, n, type);
    }
    await state.reloadAccounts();
  } catch (_) {
    if (context.mounted)
      snack(
        context,
        'Could not save. Is there already an account with this name?',
      );
  }
}

/// "Does the money I have match what the app expects?" Compares the real amount
/// with the recorded balance and offers to record the difference.
Future<void> showReconcileDialog(
  BuildContext context,
  Account account,
  double expected,
) async {
  final c = TextEditingController();
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final actual = double.tryParse(c.text.trim().replaceAll(',', ''));
        final diff = actual == null ? null : actual - expected;
        Widget msg;
        if (diff == null) {
          msg = const SizedBox.shrink();
        } else if (diff.abs() < 0.005) {
          msg = const Text(
            'Matches. Everything is recorded correctly.',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          );
        } else if (diff < 0) {
          msg = Text(
            'Rs ${Fmt.number(-diff)} is missing. That much was spent or lost but not recorded.',
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          );
        } else {
          msg = Text(
            'You have Rs ${Fmt.number(diff)} more than recorded. Some money received was not recorded.',
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w600,
            ),
          );
        }
        return AlertDialog(
          title: Text('Check ${account.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Should be: ${Fmt.money(expected)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                '(from what you recorded)',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: c,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setD(() {}),
                decoration: InputDecoration(
                  labelText: account.isCash
                      ? 'Cash in hand now (Rs)'
                      : 'Balance shown in the app/bank (Rs)',
                ),
              ),
              const SizedBox(height: 12),
              msg,
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            if (diff != null && diff < -0.005)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'expense'),
                child: const Text('Add as expense'),
              ),
            if (diff != null && diff.abs() >= 0.005)
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
                onPressed: () => Navigator.pop(ctx, 'fix'),
                child: const Text('Just fix balance'),
              ),
          ],
        );
      },
    ),
  );
  final actual = double.tryParse(c.text.trim().replaceAll(',', ''));
  c.dispose();
  if (choice == null || actual == null || !context.mounted) return;
  final state = context.read<AppState>();
  if (choice == 'expense') {
    final missing = expected - actual;
    await state.expenses.insertMany([
      Expense(
        amount: missing,
        categoryId: state.categoryByName('Other').id,
        accountId: account.id,
        description: 'Unrecorded spending (balance check)',
        date: Fmt.dateOnly(DateTime.now()),
        source: 'manual',
      ),
    ]);
  } else {
    await state.accountRepo.correctBalance(account.id, actual);
  }
  state.changed();
  if (context.mounted) {
    snack(
      context,
      choice == 'expense'
          ? 'Added Rs ${Fmt.number(expected - actual)} as an expense.'
          : 'Balance updated.',
    );
  }
}
