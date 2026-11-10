import 'package:flutter/material.dart' hide Text;

import '../services/budget_alert.dart';
import '../services/sound_service.dart';
import '../core/theme.dart';

import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../core/i18n.dart';
import '../widgets/date_sheet.dart';
import '../core/app_icons.dart';
import '../core/account_style.dart';
import '../core/category_style.dart';
import '../widgets/picker_sheet.dart';

/// Add a new expense manually, or edit/delete an existing one.
class ExpenseEditScreen extends StatefulWidget {
  final Expense? expense;
  const ExpenseEditScreen({super.key, this.expense});

  @override
  State<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends State<ExpenseEditScreen> {
  late final TextEditingController _amount;
  late final TextEditingController _desc;
  late int _categoryId;
  int? _accountId;
  late DateTime _date;

  bool get _editing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    final state = context.read<AppState>();
    _amount = TextEditingController(
      text: e == null ? '' : amountText(e.amount),
    );
    _desc = TextEditingController(text: e?.description ?? '');
    _categoryId = e?.categoryId ?? state.categoryByName('Other').id;
    _accountId = e?.accountId;
    _date = e?.date ?? Fmt.dateOnly(DateTime.now());
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDateSheet(
      context,
      initial: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = Fmt.dateOnly(d));
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      snack(context, 'Enter a valid amount greater than 0.');
      return;
    }
    if (!_editing && _accountId == null) {
      snack(context, 'Choose where you paid from.');
      return;
    }
    final state = context.read<AppState>();
    final e = Expense(
      accountId: _accountId,
      id: widget.expense?.id,
      amount: amount,
      categoryId: _categoryId,
      description: _desc.text.trim(),
      date: _date,
      source: widget.expense?.source ?? 'manual',
      rawText: widget.expense?.rawText,
    );
    if (_editing) {
      await state.expenses.update(e);
    } else {
      await state.expenses.insertMany([e]);
      SoundService.saved();
    }
    state.changed();
    BudgetAlert.check();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(
      context,
      'Delete expense?',
      'This cannot be undone.',
    ))
      return;
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    await state.expenses.delete(widget.expense!.id!);
    state.changed();
    if (!mounted) return;
    Navigator.pop(context);
    showOk(messenger, message: 'Expense deleted');
  }

  /// Small popup to change one text value (amount or description).
  Future<void> _editText({
    required String title,
    required TextEditingController target,
    bool amount = false,
  }) async {
    final c = TextEditingController(text: target.text);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: c,
              autofocus: true,
              textAlign: amount ? TextAlign.center : TextAlign.start,
              keyboardType: amount
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: amount ? [AmountFormatter()] : null,
              onSubmitted: (_) => Navigator.pop(ctx, true),
              style: amount
                  ? const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    )
                  : const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              decoration: amount
                  ? InputDecoration(
                      hintText: '0',
                      prefixText: 'Rs ',
                      prefixStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    )
                  : InputDecoration(hintText: tr('What was it for?')),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
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
                  flex: 14,
                  child: SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
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
    );
    if (ok == true && mounted) setState(() => target.text = c.text);
    c.dispose();
  }

  Future<void> _pickCategory() async {
    final cats = context.read<AppState>().categories;
    final v = await showPickerSheet<int>(
      context,
      title: 'Category',
      selected: _categoryId,
      options: [
        for (final c in cats)
          PickerOption<int>(
            value: c.id,
            label: c.name,
            leading: CategoryAvatar(c.name, radius: 14),
          ),
      ],
    );
    if (v != null && mounted) setState(() => _categoryId = v);
  }

  Future<void> _pickAccount() async {
    final accounts = context.read<AppState>().accounts;
    final allowNone = _editing && widget.expense!.accountId == null;
    const none = -1;
    final v = await showPickerSheet<int>(
      context,
      title: 'Paid from',
      selected: _accountId ?? none,
      options: [
        if (allowNone)
          PickerOption<int>(
            value: none,
            label: 'Not linked to an account',
            leading: Icon(AppIcons.wallet, size: 24, color: AppColors.muted),
          ),
        for (final a in accounts)
          PickerOption<int>(
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
    if (v != null && mounted) {
      setState(() => _accountId = v == none ? null : v);
    }
  }

  Widget _row({
    required IconData icon,
    required String label,
    required String value,
    bool verbatim = false,
    required VoidCallback onTap,
  }) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 19, color: AppColors.ink),
    ),
    title: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
      ),
    ),
    subtitle: Text(
      value,
      verbatim: verbatim,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    ),
    trailing: Icon(AppIcons.chevronRight, color: AppColors.muted, size: 20),
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cat = state.categoryById(_categoryId);
    final catName = cat?.name ?? 'Other';
    String? accName;
    for (final a in state.accounts) {
      if (a.id == _accountId) accName = a.name;
    }
    final amount = parseAmount(_amount.text);
    final desc = _desc.text.trim();
    final meta = TextStyle(fontSize: 12.5, color: AppColors.muted);
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit expense' : 'Add expense')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CategoryStyle.icon(catName),
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  desc.isEmpty ? catName : desc,
                  verbatim: desc.isNotEmpty,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    Fmt.money(amount ?? 0),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  children: [
                    Text(catName, style: meta),
                    if (accName != null) ...[
                      Text('·', verbatim: true, style: meta),
                      Text(accName, verbatim: true, style: meta),
                    ],
                    Text('·', verbatim: true, style: meta),
                    Text(Fmt.dayShort(_date), verbatim: true, style: meta),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TileGroup(
            children: [
              _row(
                icon: AppIcons.payments,
                label: 'Amount',
                value: amount == null ? tr('Not set') : Fmt.money(amount),
                onTap: () => _editText(
                  title: 'Amount',
                  target: _amount,
                  amount: true,
                ),
              ),
              _row(
                icon: AppIcons.editNote,
                label: 'Description',
                value: desc.isEmpty ? tr('Not set') : desc,
                verbatim: desc.isNotEmpty,
                onTap: () => _editText(title: 'Description', target: _desc),
              ),
              _row(
                icon: CategoryStyle.icon(catName),
                label: 'Category',
                value: catName,
                onTap: _pickCategory,
              ),
              _row(
                icon: AppIcons.wallet,
                label: 'Paid from',
                value: accName ?? tr('Not linked to an account'),
                verbatim: accName != null,
                onTap: _pickAccount,
              ),
              _row(
                icon: AppIcons.calendar,
                label: 'Date',
                value: Fmt.date(_date),
                verbatim: true,
                onTap: _pickDate,
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              if (_editing) ...[
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: FilledButton.tonal(
                      onPressed: _delete,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger.withOpacity(0.10),
                        foregroundColor: AppColors.danger,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 16,
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      _editing ? 'Save changes' : 'Add expense',
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
        ),
      ),
    );
  }
}
