import 'package:flutter/material.dart';

import 'theme.dart';
import 'app_icons.dart';

class AccountStyle {
  static IconData icon(String type) {
    switch (type) {
      case 'cash':
        return AppIcons.payments;
      case 'bank':
        return AppIcons.bank;
      default:
        return AppIcons.wallet;
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
