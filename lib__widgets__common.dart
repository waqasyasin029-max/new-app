import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/category_style.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../state/app_state.dart';

class CategoryAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const CategoryAvatar(this.name, {super.key, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final c = CategoryStyle.color(name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: c.withOpacity(0.15),
      child: Icon(CategoryStyle.icon(name), color: c, size: radius),
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDate;
  const ExpenseTile({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final cat = expense.categoryName ?? 'Other';
    final title = expense.description.isEmpty ? cat : expense.description;
    return ListTile(
      onTap: onTap,
      leading: CategoryAvatar(cat),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(showDate ? '$cat • ${Fmt.dayShort(expense.date)}' : cat),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Fmt.money(expense.amount),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final IconData icon;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: c),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: c, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryDropdown extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool allowAll;
  final String label;
  const CategoryDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowAll = false,
    this.label = 'Category',
  });

  @override
  Widget build(BuildContext context) {
    final cats = context.read<AppState>().categories;
    return DropdownButtonFormField<int?>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        if (allowAll)
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('All categories'),
          ),
        for (final c in cats)
          DropdownMenuItem<int?>(
            value: c.id,
            child: Row(
              children: [
                CategoryAvatar(c.name, radius: 12),
                const SizedBox(width: 8),
                Text(c.name),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = Fmt.firstOfMonth(DateTime.now());
    final canNext = month.isBefore(now);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1, 1)),
        ),
        Text(Fmt.month(month), style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: canNext
              ? () => onChanged(DateTime(month.year, month.month + 1, 1))
              : null,
        ),
      ],
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String message, {
  String action = 'Delete',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Returns a positive amount or null.
double? parseAmount(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', ''));
  return (v != null && v > 0 && v.isFinite) ? v : null;
}

void snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
