import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/account_style.dart';
import '../core/category_style.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../core/i18n.dart';

class CategoryAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const CategoryAvatar(this.name, {super.key, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final c = CategoryStyle.color(name);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(radius * 0.7),
      ),
      child: Icon(CategoryStyle.icon(name), color: c, size: radius * 0.95),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: CategoryAvatar(cat),
      title: Text(
        title,
        verbatim: expense.description.isNotEmpty,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          tr(cat),
          if (showDate) Fmt.dayShort(expense.date),
          if (expense.accountName != null) tr(expense.accountName!),
        ].join(' • '),
        verbatim: true,
        style: TextStyle(color: AppColors.muted, fontSize: 12.5),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Fmt.money(expense.amount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_rounded, color: AppColors.muted),
              tooltip: tr('Delete'),
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
    final c = color ?? AppColors.primary;
    return AppCard(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: c),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ),
        ],
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
      borderRadius: BorderRadius.circular(16),
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: tr(label)),
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
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () =>
                  onChanged(DateTime(month.year, month.month - 1, 1)),
            ),
            SizedBox(
              width: 150,
              child: Text(
                Fmt.month(month),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: canNext
                  ? () => onChanged(DateTime(month.year, month.month + 1, 1))
                  : null,
            ),
          ],
        ),
      ),
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
          style: FilledButton.styleFrom(
            minimumSize: const Size(90, 44),
            backgroundColor: action == 'Delete' ? AppColors.danger : null,
          ),
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

/// "Paid from" selector. [value] null = nothing chosen yet.
class AccountDropdown extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final String label;
  final String? errorText;
  final int? excludeId;
  final bool allowNone;
  const AccountDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Paid from',
    this.errorText,
    this.excludeId,
    this.allowNone = false,
  });

  @override
  Widget build(BuildContext context) {
    final accounts = context
        .read<AppState>()
        .accounts
        .where((a) => a.id != excludeId)
        .toList();
    final valid = accounts.any((a) => a.id == value);
    return DropdownButtonFormField<int?>(
      borderRadius: BorderRadius.circular(16),
      value: valid || (allowNone && value == null) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: tr(label),
        errorText: errorText == null ? null : tr(errorText!),
      ),
      items: [
        if (allowNone)
          const DropdownMenuItem<int?>(
            value: null,
            child: Text('Not linked to an account'),
          ),
        for (final a in accounts)
          DropdownMenuItem<int?>(
            value: a.id,
            child: Row(
              children: [
                Icon(
                  AccountStyle.icon(a.type),
                  size: 18,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(a.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Tap-to-choose account chips (used to set one account for many items).
class AccountChips extends StatelessWidget {
  final int? selectedId;
  final ValueChanged<int> onSelected;
  const AccountChips({
    super.key,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AppState>().accounts;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final a in accounts)
          ChoiceChip(
            avatar: Icon(AccountStyle.icon(a.type), size: 16),
            label: Text(a.name),
            selected: selectedId == a.id,
            selectedColor: AccountStyle.tint(a.type),
            onSelected: (_) => onSelected(a.id),
          ),
      ],
    );
  }
}
