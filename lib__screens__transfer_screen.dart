import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Move money between accounts. In [withdraw] mode it records an ATM/cash withdrawal into Cash.
class TransferScreen extends StatefulWidget {
  final int? fromId;
  final bool withdraw;
  const TransferScreen({super.key, this.fromId, this.withdraw = false});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _amount = TextEditingController();
  final _fee = TextEditingController();
  final _note = TextEditingController();
  int? _from;
  int? _to;
  DateTime _date = Fmt.dateOnly(DateTime.now());
  Map<int, double> _bal = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _from = widget.fromId;
    if (widget.withdraw) {
      for (final a in state.accounts) {
        if (a.isCash) _to = a.id;
      }
    }
    state.accountRepo.balances().then((l) {
      if (mounted)
        setState(() => _bal = {for (final b in l) b.account.id: b.balance});
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _fee.dispose();
    _note.dispose();
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
    final feeText = _fee.text.trim();
    final fee = feeText.isEmpty
        ? 0.0
        : (double.tryParse(feeText.replaceAll(',', '')) ?? -1);
    if (_from == null || _to == null) {
      snack(context, 'Choose both accounts.');
      return;
    }
    if (_from == _to) {
      snack(context, 'Pick two different accounts.');
      return;
    }
    if (amount == null) {
      snack(context, 'Enter a valid amount.');
      return;
    }
    if (fee < 0) {
      snack(context, 'Fee is not a valid number.');
      return;
    }
    final available = _bal[_from!] ?? 0;
    if (amount + fee > available) {
      final ok = await confirmDialog(
        context,
        'Not enough recorded balance',
        'Recorded balance is ${Fmt.money(available)} but you are moving ${Fmt.money(amount + fee)}. '
            'Your recorded balance may be out of date. Continue anyway?',
        action: 'Continue',
      );
      if (!ok) return;
    }
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final toName = state.accounts.firstWhere((a) => a.id == _to).name;
    final fromName = state.accounts.firstWhere((a) => a.id == _from).name;
    try {
      await state.accountRepo.addTransfer(
        fromId: _from!,
        toId: _to!,
        amount: amount,
        fee: fee,
        date: _date,
        note: _note.text.trim(),
      );
      state.changed();
      final newTo = await state.accountRepo.balanceOf(_to!);
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            '${Fmt.money(amount)} moved from $fromName to $toName.\n$toName now: ${Fmt.money(newTo)}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        snack(context, 'Could not save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.withdraw;
    return Scaffold(
      appBar: AppBar(title: Text(w ? 'Withdraw cash' : 'Transfer money')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (w)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Record when you took money out (ATM or agent). It is added to your Cash and taken from the account you choose.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          AccountDropdown(
            label: w ? 'Withdrawn from account' : 'From account',
            value: _from,
            excludeId: _to,
            onChanged: (v) => setState(() => _from = v),
          ),
          if (_from != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 0, 0),
              child: Text(
                'Recorded balance: ${Fmt.money(_bal[_from!] ?? 0)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 16),
          AccountDropdown(
            label: w ? 'Money goes to' : 'To account',
            value: _to,
            excludeId: _from,
            onChanged: (v) => setState(() => _to = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: w,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: w ? 'How much did you withdraw? (Rs)' : 'Amount (Rs)',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _fee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fee / charges (optional)',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(
              w ? 'Withdrawn on: ${Fmt.date(_date)}' : Fmt.date(_date),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(w ? 'Save withdrawal' : 'Save transfer'),
          ),
        ],
      ),
    );
  }
}
