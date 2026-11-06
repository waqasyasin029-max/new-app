import 'package:flutter/material.dart';

class CategoryStyle {
  static IconData icon(String name) {
    switch (name) {
      case 'Food':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_car;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Bills':
        return Icons.receipt_long;
      case 'Groceries':
        return Icons.local_grocery_store;
      case 'Health':
        return Icons.medical_services;
      case 'Entertainment':
        return Icons.movie;
      default:
        return Icons.category;
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
