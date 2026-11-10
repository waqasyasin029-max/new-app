import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/account_style.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/account_dialogs.dart';
import '../widgets/common.dart';
import '../widgets/activity_tile.dart';
import '../widgets/data_loader.dart';
import '../widgets/transfer_sheet.dart';
import '../core/i18n.dart';
import '../core/app_icons.dart';

class _Detail {
  final double balance;
  final List<ActivityItem> items;
  _Detail(this.balance, this.items);
}

class AccountDetailScreen extends StatelessWidget {
  final int accountId;
  const AccountDetailScreen({super.key, required this.accountId});

  Future<void> _addMoney(BuildContext context, Account a) async {
    final amount = TextEditingController();
    final note = TextEditingController(text: 'Money added');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add money to ${a.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [AmountFormatter()],
              decoration: InputDecoration(labelText: tr('Amount (Rs)')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: InputDecoration(
                labelText: tr('Source (salary, received…)'),
              ),
            ),
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
              if (parseAmount(amount.text) == null) {
                snack(ctx, 'Enter a valid amount.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final v = parseAmount(amount.text);
    final n = note.text.trim();
    amount.dispose();
    note.dispose();
    if (ok != true || v == null || !context.mounted) return;
    final state = context.read<AppState>();
    await state.incomes.addExtra(
      v,
      n.isEmpty ? 'Money added' : n,
      Fmt.dateOnly(DateTime.now()),
      accountId: a.id,
    );
    state.changed();
    if (context.mounted) snackOk(context, 'Money added');
  }

  Future<void> _delete(BuildContext context, Account a) async {
    final state = context.read<AppState>();
    if (await state.accountRepo.hasActivity(a.id)) {
      if (context.mounted)
        snack(
          context,
          'This account has transactions, so it cannot be deleted.',
        );
      return;
    }
    if (!context.mounted) return;
    if (!await confirmDialog(
      context,
      'Delete ${a.name}?',
      'This account has no transactions.',
    ))
      return;
    final messenger = ScaffoldMessenger.of(context);
    await state.accountRepo.delete(a.id);
    await state.reloadAccounts();
    if (!context.mounted) return;
    Navigator.pop(context);
    showOk(messenger, message: 'Account deleted');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    Account? acc;
    for (final a in state.accounts) {
      if (a.id == accountId) acc = a;
    }
    if (acc == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final a = acc;
    return Scaffold(
      appBar: AppBar(
        title: Text(a.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') showAccountDialog(context, existing: a);
              if (v == 'delete') _delete(context, a);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Rename / change type')),
              PopupMenuItem(value: 'delete', child: Text('Delete account')),
            ],
          ),
        ],
      ),
      body: DataLoader<_Detail>(
        depends: a.id,
        load: (s) async => _Detail(
          await s.accountRepo.balanceOf(a.id),
          await s.accountRepo.activity(a.id),
        ),
        builder: (context, d) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.fieldFill,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            AccountStyle.icon(a.type),
                            color: AppColors.ink,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${AccountStyle.label(a.type)} balance (recorded)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.muted,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  Fmt.money(d.balance),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: d.balance < 0
                                        ? AppColors.danger
                                        : AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () =>
                            showReconcileDialog(context, a, d.balance),
                        icon: const Icon(AppIcons.factCheck, size: 18),
                        label: const Text(
                          'Check balance',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _tonal(
                            icon: a.isCash ? AppIcons.swapHoriz : AppIcons.atm,
                            label: a.isCash ? 'Transfer out' : 'Withdraw',
                            onTap: () => showTransferSheet(
                              context,
                              fromId: a.id,
                              withdraw: !a.isCash,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _tonal(
                            icon: AppIcons.add,
                            label: 'Add money',
                            onTap: () => _addMoney(context, a),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionTitle('Activity'),
              if (d.items.isEmpty)
                AppCard(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Nothing recorded for this account yet.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                for (final g in groupActivityByDay(d.items)) ...[
                  ActivityDayHeader(g.key),
                  TileGroup(
                    children: [
                      for (final i in g.value)
                        ActivityTile(
                          item: i,
                          action: i.kind == 'expense'
                              ? null
                              : IconButton(
                                  icon: Icon(
                                    AppIcons.delete,
                                    color: AppColors.muted,
                                  ),
                                  onPressed: () async {
                                    if (!await confirmDialog(
                                      context,
                                      'Delete this entry?',
                                      '${i.title} – ${Fmt.money(i.delta.abs())}',
                                    ))
                                      return;
                                    final s = context.read<AppState>();
                                    if (i.kind == 'transfer') {
                                      await s.accountRepo.deleteTransfer(i.id);
                                    } else {
                                      await s.incomes.delete(i.id);
                                    }
                                    s.changed();
                                    if (context.mounted) {
                                      snackOk(context, 'Entry deleted');
                                    }
                                  },
                                ),
                        ),
                    ],
                  ),
                ],
              Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  'Expenses are edited or deleted from the History tab.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tonal({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => SizedBox(
    height: 46,
    child: FilledButton.tonalIcon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.fieldFill,
        foregroundColor: AppColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
      ),
    ),
  );
}
