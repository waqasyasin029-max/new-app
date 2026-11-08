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
      body: DataLoader<List<AccountBalance>>(
        load: (s) => s.accountRepo.balances(),
        builder: (context, list) {
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
              const SizedBox(height: 8),
              for (final b in list)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Material(
                    color: AccountStyle.tint(b.account.type),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => _open(
                        context,
                        AccountDetailScreen(accountId: b.account.id),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
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
            ],
          );
        },
      ),
    );
  }
}
