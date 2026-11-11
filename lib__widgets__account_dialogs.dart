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
                      inputFormatters: [AmountFormatter()],
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
    if (context.mounted) {
      snackOk(context, existing == null ? 'Account added' : 'Changes saved');
    }
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
  final choice = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final actual = double.tryParse(c.text.trim().replaceAll(',', ''));
        final diff = actual == null ? null : actual - expected;
        final matched = diff != null && diff.abs() < 0.005;
        final less = diff != null && diff < -0.005;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
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
                        AppIcons.factCheck,
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
                            'Check ${account.name}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            account.isCash
                                ? 'How much cash is in your hand right now?'
                                : 'How much does your bank or wallet app show right now?',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Actual balance',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                TextField(
                  controller: c,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [AmountFormatter()],
                  onChanged: (_) => setD(() {}),
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
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'In the app: ${Fmt.money(expected)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (diff != null) ...[
                  const SizedBox(height: 14),
                  if (matched)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.positive.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'Matches. Everything is recorded correctly.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.positive,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (less ? AppColors.danger : AppColors.gold)
                            .withOpacity(0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${less ? '-' : '+'} ${Fmt.money(diff.abs())}',
                            verbatim: true,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: less
                                  ? AppColors.danger
                                  : const Color(0xFFB98500),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              less
                                  ? 'That much was spent or lost but not recorded.'
                                  : 'Some money received was not recorded.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                if (diff == null || matched)
                  SizedBox(
                    height: 54,
                    child: matched
                        ? FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: _sheetBtn(),
                            child: const Text('Done', style: _btnText),
                          )
                        : FilledButton.tonal(
                            onPressed: () => Navigator.pop(ctx),
                            style: _sheetBtn(tonal: true),
                            child: const Text('Close', style: _btnText),
                          ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 10,
                        child: SizedBox(
                          height: 54,
                          child: FilledButton.tonal(
                            onPressed: () => Navigator.pop(
                              ctx,
                              less ? 'expense' : null,
                            ),
                            style: _sheetBtn(tonal: true),
                            child: Text(
                              less ? 'Add as expense' : 'Cancel',
                              textAlign: TextAlign.center,
                              style: _btnText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 13,
                        child: SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, 'fix'),
                            style: _sheetBtn(),
                            child: const Text(
                              'Just fix balance',
                              textAlign: TextAlign.center,
                              style: _btnText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (less)
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ),
                ],
              ],
            ),
          ),
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
    snackOk(
      context,
      choice == 'expense'
          ? 'Added Rs ${Fmt.number(expected - actual)} as an expense.'
          : 'Balance updated.',
    );
  }
}

const _btnText = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800);

ButtonStyle _sheetBtn({bool tonal = false}) => FilledButton.styleFrom(
  backgroundColor: tonal ? AppColors.fieldFill : null,
  foregroundColor: tonal ? AppColors.ink : null,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
);
