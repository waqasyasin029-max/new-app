import 'package:flutter/material.dart' hide Text;

import '../core/account_style.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/account_dialogs.dart';
import '../widgets/data_loader.dart';
import 'account_detail_screen.dart';
import 'transfer_screen.dart';
import '../core/i18n.dart';
import '../core/app_icons.dart';

class _Data {
  final List<AccountBalance> balances;
  final List<ActivityItem> activity;
  _Data(this.balances, this.activity);
}

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: tr('Add account'),
            icon: const Icon(AppIcons.addCircle),
            onPressed: () => showAccountDialog(context),
          ),
        ],
      ),
      body: DataLoader<_Data>(
        load: (s) async =>
            _Data(await s.accountRepo.balances(), await s.accountRepo.allActivity()),
        builder: (context, data) {
          final list = data.balances;
          final total = list.fold<double>(0, (a, b) => a + b.balance);
          final allZero = list.every((b) => b.balance == 0);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.gradient,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total money you have',
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Fmt.money(total),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.navy,
                            ),
                            onPressed: () => _open(
                              context,
                              const TransferScreen(withdraw: true),
                            ),
                            icon: const Icon(AppIcons.atm, size: 20),
                            label: const Text('Withdraw'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.ink,
                            ),
                            onPressed: () =>
                                _open(context, const TransferScreen()),
                            icon: const Icon(AppIcons.swapHoriz, size: 20),
                            label: const Text('Transfer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (allZero)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.noteBg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'First step: open each account below, tap "Check balance" and enter how much it really has right now. '
                      'After that the app keeps every balance up to date.',
                    ),
                  ),
                ),
              const SectionTitle('My accounts'),
              for (final b in list)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: AccountStyle.tint(b.account.type),
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => _open(
                        context,
                        AccountDetailScreen(accountId: b.account.id),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.softWhite,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                AccountStyle.icon(b.account.type),
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.account.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    AccountStyle.label(b.account.type),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Fmt.money(b.balance),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: b.balance < 0
                                    ? AppColors.danger
                                    : AppColors.ink,
                              ),
                            ),
                            const Icon(AppIcons.chevronRight),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SectionTitle('Activity · all accounts'),
              if (data.activity.isEmpty)
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'Nothing recorded yet.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else ...[
                for (final g in _groups(data.activity)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                    child: Text(
                      Fmt.dayLabel(g.key),
                      verbatim: true,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  TileGroup(
                    children: [
                      for (final i in g.value) _activityRow(context, i),
                    ],
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
                  child: Text(
                    'Showing the latest entries. Open an account to see more.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Groups the (already sorted) items by day, keeping the order.
  List<MapEntry<DateTime, List<ActivityItem>>> _groups(
    List<ActivityItem> items,
  ) {
    final out = <MapEntry<DateTime, List<ActivityItem>>>[];
    for (final i in items) {
      final d = Fmt.dateOnly(i.date);
      if (out.isEmpty || out.last.key != d) {
        out.add(MapEntry(d, <ActivityItem>[]));
      }
      out.last.value.add(i);
    }
    return out;
  }

  Widget _activityRow(BuildContext context, ActivityItem i) {
    final isIn = i.kind == 'deposit';
    final isTransfer = i.kind == 'transfer';
    final color = isTransfer
        ? AppColors.muted
        : (isIn ? AppColors.positive : AppColors.danger);
    final icon = isTransfer
        ? AppIcons.swapHoriz
        : (isIn ? AppIcons.arrowDownLeft : AppIcons.arrowUpRight);
    final sign = isTransfer ? '' : (isIn ? '+' : '-');
    return ListTile(
      onTap: () => _open(context, AccountDetailScreen(accountId: i.accountId)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 17, color: color),
      ),
      title: Text(
        i.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                i.account,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ),
            if (isTransfer && i.subtitle.isNotEmpty)
              Text(
                i.subtitle,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
          ],
        ),
      ),
      trailing: Text(
        '$sign${Fmt.money(i.delta.abs())}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isIn ? AppColors.positive : AppColors.ink,
        ),
      ),
    );
  }
}
