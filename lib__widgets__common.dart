import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/account_style.dart';
import '../core/category_style.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../core/i18n.dart';
import '../core/app_icons.dart';

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
              icon: Icon(AppIcons.delete, color: AppColors.muted),
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
              icon: const Icon(AppIcons.chevronLeft),
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
              icon: const Icon(AppIcons.chevronRight),
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
/// Types amounts with thousands separators: 1,000 and 25,000.50.
/// Only digits and one decimal point (two decimals at most) are accepted.
class AmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(raw)) return oldValue;
    final dot = raw.indexOf('.');
    var whole = dot < 0 ? raw : raw.substring(0, dot);
    final dec = dot < 0 ? '' : raw.substring(dot + 1);
    if (dec.length > 2) return oldValue;
    whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.isEmpty) whole = '0';
    final sb = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) sb.write(',');
      sb.write(whole[i]);
    }
    final text = '$sb${dot < 0 ? '' : '.$dec'}';
    // Keep the cursor after the same number of digits as before.
    final end = newValue.selection.end.clamp(0, newValue.text.length);
    final before = newValue.text.substring(0, end).replaceAll(',', '').length;
    var seen = 0;
    var pos = 0;
    while (pos < text.length && seen < before) {
      if (text[pos] != ',') seen++;
      pos++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: pos),
    );
  }
}

double? parseAmount(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', ''));
  return (v != null && v > 0 && v.isFinite) ? v : null;
}

OverlayEntry? _errorEntry;
Timer? _errorTimer;

void _closeError() {
  _errorTimer?.cancel();
  _errorEntry?.remove();
  _errorEntry = null;
}

/// Red error message at the top of the screen for 3 seconds. No shadow. It
/// sits above popups too, so a mistake made inside a dialog is visible.
void snack(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _closeError();
  final top = MediaQuery.of(context).padding.top;
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      top: top + 12,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (v - 1) * 16),
            child: child,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ToastCard(
            kind: ToastKind.error,
            content: Text(message),
            onClose: _closeError,
          ),
        ),
      ),
    ),
  );
  _errorEntry = entry;
  overlay.insert(entry);
  _errorTimer = Timer(const Duration(seconds: 3), () {
    if (_errorEntry == entry) _closeError();
  });
}

enum ToastKind { ok, error, info }

/// Soft tinted message card: coloured icon, bold coloured text, close button.
/// Used for every snackbar so they all look the same.
class ToastCard extends StatelessWidget {
  final ToastKind kind;
  final Widget content;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClose;
  const ToastCard({
    super.key,
    required this.kind,
    required this.content,
    required this.onClose,
    this.actionLabel,
    this.onAction,
  });

  Color get _fg {
    final d = AppColors.dark;
    switch (kind) {
      case ToastKind.ok:
        return d ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
      case ToastKind.error:
        return d ? const Color(0xFFFF8A8F) : const Color(0xFFC62828);
      case ToastKind.info:
        return d ? const Color(0xFF7DB4FF) : const Color(0xFF1D5FD1);
    }
  }

  Color get _bg {
    final d = AppColors.dark;
    switch (kind) {
      case ToastKind.ok:
        return d ? const Color(0xFF14291D) : const Color(0xFFE9F8EF);
      case ToastKind.error:
        return d ? const Color(0xFF331618) : const Color(0xFFFDECEC);
      case ToastKind.info:
        return d ? const Color(0xFF14233A) : const Color(0xFFE8F2FE);
    }
  }

  Widget _icon() {
    switch (kind) {
      case ToastKind.ok:
        return Icon(AppIcons.check, size: 24, color: _fg);
      case ToastKind.info:
        return Icon(AppIcons.info, size: 24, color: _fg);
      case ToastKind.error:
        return Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _fg, width: 2),
          ),
          child: Text(
            '!',
            verbatim: true,
            style: TextStyle(
              color: _fg,
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _fg.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          _icon(),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: _fg,
                fontSize: 14.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
              child: content,
            ),
          ),
          if (actionLabel != null)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: _fg,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: () {
                onClose();
                onAction?.call();
              },
              child: Text(actionLabel!, verbatim: true),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(AppIcons.close, size: 18, color: _fg),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// Bottom message (green by default). It goes away by itself after 5 seconds,
/// even when it has an Undo button.
void showOk(
  ScaffoldMessengerState messenger, {
  String? message,
  Widget? content,
  SnackBarAction? action,
  ToastKind kind = ToastKind.ok,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 5),
        persist: false,
        content: ToastCard(
          kind: kind,
          content: content ?? Text(message ?? ''),
          actionLabel: action?.label,
          onAction: action?.onPressed,
          onClose: messenger.hideCurrentSnackBar,
        ),
      ),
    );
}

void snackOk(BuildContext context, String message) =>
    showOk(ScaffoldMessenger.of(context), message: message);

/// Blue neutral note ("Checking…", "A reminder will arrive…").
void snackInfo(BuildContext context, String message) => showOk(
  ScaffoldMessenger.of(context),
  message: message,
  kind: ToastKind.info,
);

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
