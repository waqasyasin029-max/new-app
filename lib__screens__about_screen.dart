import 'package:flutter/material.dart' hide Text;

import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/update_service.dart';
import '../widgets/common.dart';
import '../core/app_icons.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _features = <(IconData, String)>[
    (
      AppIcons.editNote,
      'Add an expense in seconds: amount, category and account',
    ),
    (AppIcons.factCheck, 'Check and fix everything before it is saved'),
    (AppIcons.wallet, 'Cash, wallets and bank accounts with balances'),
    (AppIcons.swapHoriz, 'Withdraw, transfer and reconcile between accounts'),
    (AppIcons.barChart, 'History, reports and a monthly budget'),
    (AppIcons.bellRinging, 'A daily reminder to write your expenses'),
    (AppIcons.wifiOff, 'Works offline, no sign-up'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Image.asset('assets/icon/logo.png'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kharcha Tracker',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your daily expense diary',
                  style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    kBuildNumber == 0
                        ? 'Development build'
                        : 'Version $kBuildNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('What it does'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final f in _features)
                  ListTile(
                    dense: true,
                    leading: Icon(f.$1, color: AppColors.primary),
                    title: Text(f.$2, style: const TextStyle(fontSize: 14)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          AppCard(
            child: ListTile(
              leading: const Icon(AppIcons.lock, color: AppColors.primary),
              title: const Text(
                'Your data stays on this phone',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Center(
            child: Column(
              children: [
                Text(
                  'Developed by',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Waqas Yasin',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Made in Pakistan',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
