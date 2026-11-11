import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/account_style.dart';
import '../core/category_style.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../main.dart' show navigatorKey;
import '../data/models.dart';
import '../state/app_state.dart';
import '../core/i18n.dart';
import 'picker_sheet.dart';
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
    return PickerField<int?>(
      label: label,
      value: value,
      onChanged: onChanged,
      options: [
        if (allowAll)
          PickerOption<int?>(
            value: null,
            label: 'All categories',
            leading: Icon(AppIcons.category, size: 24, color: AppColors.muted),
          ),
        for (final c in cats)
          PickerOption<int?>(
            value: c.id,
            label: c.name,
            leading: CategoryAvatar(c.name, radius: 14),
          ),
      ],
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

/// Themed confirm dialog (centre of the screen). For "Delete" it is red with
/// a bin icon and says it cannot be undone; other actions use the orange style.
Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String message, {
  String action = 'Delete',
}) async {
  final danger = action == 'Delete';
  final color = danger ? AppColors.danger : AppColors.primary;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                danger ? AppIcons.delete : AppIcons.info,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            if (danger && message != 'This cannot be undone.') ...[
              const SizedBox(height: 2),
              Text(
                'This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.fieldFill,
                        foregroundColor: AppColors.ink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        action,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return r ?? false;
}

/// Asks before closing the app, in plain words: what will happen, then
/// "Stay in app" or "Yes, close app". It closes only on a clear yes.
Future<void> confirmExit(BuildContext context) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.gradient,
        ),
        child: const Icon(AppIcons.close, size: 30, color: Colors.white),
      ),
      title: const Text('Close the app?', textAlign: TextAlign.center),
      content: const Text(
        'The app will close. Your data is saved on this phone.',
        textAlign: TextAlign.center,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Stay in app'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Yes, close app'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  if (yes == true) SystemNavigator.pop();
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

/// A saved amount as the amount fields show it: 25,000 or 1,250.5.
String amountText(num v) {
  var raw = v.toStringAsFixed(2);
  raw = raw.replaceFirst(RegExp(r'\.?0+$'), '');
  return AmountFormatter()
      .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: raw))
      .text;
}

double? parseAmount(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', ''));
  return (v != null && v > 0 && v.isFinite) ? v : null;
}

OverlayEntry? _toastEntry;
Timer? _toastTimer;

void _closeToast() {
  _toastTimer?.cancel();
  _toastEntry?.remove();
  _toastEntry = null;
}

/// Every message in the app (error, saved, info) appears here: one card at
/// the top of the screen, no shadow, above popups and the bottom bar. A new
/// message replaces the old one.
void _showToast(
  ToastKind kind, {
  required Widget content,
  required Duration duration,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = navigatorKey.currentState?.overlay;
  if (overlay == null) return;
  _closeToast();
  final entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: MediaQuery.of(ctx).padding.top + 12,
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
            kind: kind,
            content: content,
            actionLabel: actionLabel,
            onAction: onAction,
            onClose: _closeToast,
          ),
        ),
      ),
    ),
  );
  _toastEntry = entry;
  overlay.insert(entry);
  _toastTimer = Timer(duration, () {
    if (_toastEntry == entry) _closeToast();
  });
}

/// Red error message, 3 seconds.
void snack(BuildContext context, String message) => _showToast(
  ToastKind.error,
  content: Text(message),
  duration: const Duration(seconds: 3),
);

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
        return Icon(AppIcons.check, size: 22, color: _fg);
      case ToastKind.info:
        return Icon(AppIcons.info, size: 22, color: _fg);
      case ToastKind.error:
        return Container(
          width: 20,
          height: 20,
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
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
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
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
              child: content,
            ),
          ),
          if (actionLabel != null)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: _fg,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
            icon: Icon(AppIcons.close, size: 16, color: _fg),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// Green message (saved, added, deleted), 5 seconds, optional Undo button.
/// [messenger] is not needed any more; it is kept so older calls still work.
void showOk(
  Object? messenger, {
  String? message,
  Widget? content,
  SnackBarAction? action,
  ToastKind kind = ToastKind.ok,
}) => _showToast(
  kind,
  content: content ?? Text(message ?? ''),
  duration: const Duration(seconds: 5),
  actionLabel: action?.label,
  onAction: action?.onPressed,
);

void snackOk(BuildContext context, String message) =>
    showOk(null, message: message);

/// Blue neutral note ("Checking…", "A reminder will arrive…").
void snackInfo(BuildContext context, String message) =>
    showOk(null, message: message, kind: ToastKind.info);

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
    return PickerField<int?>(
      label: label,
      errorText: errorText,
      value: valid || (allowNone && value == null) ? value : -1,
      onChanged: onChanged,
      options: [
        if (allowNone)
          PickerOption<int?>(
            value: null,
            label: 'Not linked to an account',
            leading: Icon(AppIcons.wallet, size: 24, color: AppColors.muted),
          ),
        for (final a in accounts)
          PickerOption<int?>(
            value: a.id,
            label: a.name,
            verbatim: true,
            leading: Icon(
              AccountStyle.icon(a.type),
              size: 24,
              color: AppColors.muted,
            ),
          ),
      ],
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
