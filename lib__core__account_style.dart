import 'package:flutter/material.dart';

import 'theme.dart';

class AccountStyle {
  static IconData icon(String type) {
    switch (type) {
      case 'cash':
        return Icons.payments_outlined;
      case 'bank':
        return Icons.account_balance_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  static Color tint(String type) {
    switch (type) {
      case 'cash':
        return AppColors.mint;
      case 'bank':
        return AppColors.sky;
      default:
        return AppColors.lavender;
    }
  }

  static String label(String type) {
    switch (type) {
      case 'cash':
        return 'Cash';
      case 'bank':
        return 'Bank';
      default:
        return 'Digital wallet';
    }
  }

  static const types = ['cash', 'wallet', 'bank'];
}
