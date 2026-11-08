import 'package:flutter/material.dart' hide Text;

import '../core/theme.dart';

import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../core/i18n.dart';
import '../core/app_icons.dart';

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
      text: e == null ? '' : Fmt.number(e.amount).replaceAll(',', ''),
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
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
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
    }
    state.changed();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit expense' : 'Add expense'),
        actions: [
          if (_editing)
            IconButton(icon: const Icon(AppIcons.delete), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _amount,
            autofocus: !_editing,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [AmountFormatter()],
            decoration: InputDecoration(labelText: tr('Amount (Rs)')),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _desc,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: tr('Description')),
          ),
          const SizedBox(height: 16),
          CategoryDropdown(
            value: _categoryId,
            onChanged: (v) => setState(() => _categoryId = v ?? _categoryId),
          ),
          const SizedBox(height: 16),
          AccountDropdown(
            value: _accountId,
            allowNone: _editing && widget.expense!.accountId == null,
            onChanged: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(AppIcons.calendar),
            label: Text(Fmt.date(_date)),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(AppIcons.check),
            label: Text(_editing ? 'Save changes' : 'Add expense'),
          ),
        ],
      ),
    );
  }
}
