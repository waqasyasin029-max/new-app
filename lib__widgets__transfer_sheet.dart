import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/account_style.dart';
import '../core/app_icons.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'date_sheet.dart';

/// Popup for moving money between accounts. In [withdraw] mode it records an
/// ATM / agent withdrawal: the money goes to Cash and leaves the chosen account.
Future<void> showTransferSheet(
  BuildContext context, {
  int? fromId,
  bool withdraw = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _TransferSheet(fromId: fromId, withdraw: withdraw),
  );
}

class _TransferSheet extends StatefulWidget {
  final int? fromId;
  final bool withdraw;
  const _TransferSheet({this.fromId, required this.withdraw});

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _amount = TextEditingController();
  final _fee = TextEditingController();
  final _note = TextEditingController();
  int? _from;
  int? _to;
  DateTime _date = Fmt.dateOnly(DateTime.now());
  Map<int, double> _bal = {};
  bool _open = false;
  bool _saving = false;
  String? _error;

  bool get _w => widget.withdraw;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final accounts = state.accounts;
    if (_w) {
      for (final a in accounts) {
        if (a.isCash) _to = a.id;
      }
      final from = accounts.where((a) => !a.isCash && a.id == widget.fromId);
      _from = from.isNotEmpty
          ? from.first.id
          : accounts.where((a) => !a.isCash).map((a) => a.id).firstOrNull;
    } else {
      _from = widget.fromId ?? accounts.map((a) => a.id).firstOrNull;
      _to = accounts.where((a) => a.id != _from).map((a) => a.id).firstOrNull;
    }
    state.accountRepo.balances().then((l) {
      if (mounted) {
        setState(() => _bal = {for (final b in l) b.account.id: b.balance});
      }
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _fee.dispose();
    _note.dispose();
    super.dispose();
  }

  String _name(int? id) {
    if (id == null) return tr('Choose');
    for (final a in context.read<AppState>().accounts) {
      if (a.id == id) return a.name;
    }
    return tr('Choose');
  }

  double get _feeValue {
    final t = _fee.text.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t.replaceAll(',', '')) ?? -1;
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

  void _fail(String m) => setState(() => _error = m);

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    final fee = _feeValue;
    if (amount == null) {
      _fail('Enter a valid amount.');
      return;
    }
    if (_from == null || _to == null) {
      _fail('Choose both accounts.');
      return;
    }
    if (_from == _to) {
      _fail('Pick two different accounts.');
      return;
    }
    if (fee < 0) {
      setState(() => _open = true);
      _fail('Fee is not a valid number.');
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
      if (!ok || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final state = context.read<AppState>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final toName = _name(_to);
    final fromName = _name(_from);
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
      showOk(
        messenger,
        message:
            '${Fmt.money(amount)} moved from $fromName to $toName.\n$toName now: ${Fmt.money(newTo)}',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _fail('Could not save: $e');
      }
    }
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
      ),
    ),
  );

  Widget _chips({
    required List<Account> accounts,
    required int? selected,
    required ValueChanged<int> onPick,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final a in accounts)
        ChoiceChip(
          avatar: Icon(AccountStyle.icon(a.type), size: 16),
          label: Text(a.name, verbatim: true),
          selected: selected == a.id,
          showCheckmark: false,
          onSelected: (_) => onPick(a.id),
        ),
    ],
  );

  Widget _details(List<Account> accounts) {
    final fromList = accounts
        .where((a) => a.id != _to && !(_w && a.isCash))
        .toList();
    final toList = accounts.where((a) => a.id != _from).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(_w ? 'Withdrawn from account' : 'From account'),
        _chips(
          accounts: fromList,
          selected: _from,
          onPick: (id) => setState(() => _from = id),
        ),
        if (!_w) ...[
          _label('To account'),
          _chips(
            accounts: toList,
            selected: _to,
            onPick: (id) => setState(() => _to = id),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _fee,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [AmountFormatter()],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: tr('Fee / charges (optional)')),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(AppIcons.calendar, size: 18),
          label: Text(Fmt.date(_date), verbatim: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: InputDecoration(labelText: tr('Note (optional)')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accounts = context.watch<AppState>().accounts;
    final fee = _feeValue;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        16 + MediaQuery.of(context).viewInsets.bottom,
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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _w ? AppIcons.atm : AppIcons.swapHoriz,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _w ? 'Withdraw cash' : 'Transfer money',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _w
                          ? 'Cash you took out is added to your Cash.'
                          : 'Move money from one account to another.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _w ? 'Withdrawn amount' : 'Amount',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ),
          TextField(
            controller: _amount,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [AmountFormatter()],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: 'Rs ',
              prefixStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
          Center(
            child: Material(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _name(_from),
                        verbatim: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        AppIcons.arrowForward,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _name(_to),
                        verbatim: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        AppIcons.edit,
                        size: 14,
                        color: Color(0xFFC9C9D2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              if (_from != null)
                Text(
                  'Recorded balance: ${Fmt.money(_bal[_from!] ?? 0)}',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              if (fee > 0) ...[
                Text('·', verbatim: true, style: TextStyle(color: AppColors.muted)),
                Text(
                  'fee ${Fmt.money(fee)}',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
              Text('·', verbatim: true, style: TextStyle(color: AppColors.muted)),
              Text(
                Fmt.dayShort(_date),
                verbatim: true,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _open = !_open),
              child: Text(
                _open ? 'Hide details' : 'Change accounts, fee, date or note',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _open ? _details(accounts) : const SizedBox(width: double.infinity),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 10,
                child: SizedBox(
                  height: 54,
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.fieldFill,
                      foregroundColor: AppColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      _w ? 'Save withdrawal' : 'Save transfer',
                      style: const TextStyle(
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
    );
  }
}
