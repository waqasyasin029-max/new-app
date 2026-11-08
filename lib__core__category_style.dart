import 'package:flutter/material.dart';

class CategoryStyle {
  static IconData icon(String name) {
    switch (name) {
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Transport':
        return Icons.directions_car_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Bills':
        return Icons.receipt_long_rounded;
      case 'Groceries':
        return Icons.local_grocery_store_rounded;
      case 'Health':
        return Icons.medical_services_rounded;
      case 'Entertainment':
        return Icons.movie_rounded;
      default:
        return Icons.category_rounded;
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
