import 'package:flutter/material.dart';

import 'app_icons.dart';

class CategoryStyle {
  static IconData icon(String name) {
    switch (name) {
      case 'Food':
        return AppIcons.restaurant;
      case 'Transport':
        return AppIcons.car;
      case 'Shopping':
        return AppIcons.shoppingBag;
      case 'Bills':
        return AppIcons.receipt;
      case 'Groceries':
        return AppIcons.grocery;
      case 'Health':
        return AppIcons.medical;
      case 'Entertainment':
        return AppIcons.movie;
      default:
        return AppIcons.category;
    }
  }

  static Color color(String name) {
    switch (name) {
      case 'Food':
        return Colors.orange;
      case 'Transport':
        return Colors.blue;
      case 'Shopping':
        return Colors.pink;
      case 'Bills':
        return Colors.red;
      case 'Groceries':
        return Colors.green;
      case 'Health':
        return Colors.teal;
      case 'Entertainment':
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }
}
