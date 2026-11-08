import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/account_style.dart';
import '../core/app_icons.dart';
import '../core/format.dart';
import '../core/pk_accounts.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'common.dart';
import '../core/i18n.dart';

/// Add a new account or rename / retype an existing one.
Future<void> showAccountDialog(
  BuildContext context, {
  Account? existing,
}) async {
  const other = '__other__';
  final name = TextEditingController(text: existing?.name ?? '');
  final balance = TextEditingController();
  var type = existing?.type ?? 'wallet';
  final taken = {
    for (final a in context.read<AppState>().accounts) a.name.toLowerCase(),
  };
  final choices = [
    for (final a in PkAccounts.all)
      if (!taken.contains(a.name.toLowerCase())) a,
  ];
  String? pick; // a ready-made account name, or [other]
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final typing = existing != null || pick == other;
        return AlertDialog(
          title: Text(existing == null ? 'Add account' : 'Edit account'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (existing == null) ...[
                    DropdownButtonFormField<String>(
                      borderRadius: BorderRadius.circular(16),
                      menuMaxHeight: 340,
                      isExpanded: true,
                      value: pick,
                      decoration: InputDecoration(labelText: tr('Account')),
                      hint: Text('Choose an account'),
                      items: [
                        for (final a in choices)
                          DropdownMenuItem(
                            value: a.name,
                            child: Row(
                              children: [
                                Icon(AccountStyle.icon(a.type), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    a.name,
                                    verbatim: a.type != 'cash',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        DropdownMenuItem(
                          value: other,
                          child: Row(
                            children: [
                              const Icon(AppIcons.edit, size: 18),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text('Other (write the name)'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) => setD(() => pick = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (typing) ...[
                    TextField(
                      controller: name,
                      autofocus: existing != null || pick == other,
                      decoration: InputDecoration(
                        labelText: tr('Name (e.g. HBL, SadaPay)'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      borderRadius: BorderRadius.circular(16),
                      value: type,
                      decoration: InputDecoration(labelText: tr('Type')),
                      items: [
                        for (final t in AccountStyle.types)
                          DropdownMenuItem(
                            value: t,
                            child: Text(AccountStyle.label(t)),
                          ),
                      ],
                      onChanged: (v) => setD(() => type = v ?? type),
                    ),
                  ],
                  if (existing == null && pick != null) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: balance,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: tr('Money in it right now (Rs)'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
              onPressed: () {
                if (existing == null && pick == null) {
                  snack(ctx, 'Choose an account.');
                  return;
                }
                if ((existing != null || pick == other) &&
                    name.text.trim().isEmpty) {
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
        );
      },
    ),
  );
  final n = pick == null || pick == other ? name.text.trim() : pick!;
  if (existing == null && pick != null && pick != other) {
    for (final a in PkAccounts.all) {
      if (a.name == pick) type = a.type;
    }
  }
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
              color: AppColors.positive,
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
              Text(
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
                  labelText: tr(
                    account.isCash
                        ? 'Cash in hand now (Rs)'
                        : 'Balance shown in the app/bank (Rs)',
                  ),
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
