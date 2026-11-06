import 'package:flutter/material.dart';

import '../core/theme.dart';

import 'package:provider/provider.dart';

import '../core/format.dart';
import '../data/models.dart';
import '../logic/expense_parser.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class _Draft {
  final TextEditingController amount;
  final TextEditingController desc;
  final String heard;
  int categoryId;
  bool include = true;
  final bool amountMissing;

  _Draft({
    required double? amt,
    required String description,
    required this.categoryId,
    required this.heard,
  }) : amount = TextEditingController(
         text: amt == null ? '' : Fmt.number(amt).replaceAll(',', ''),
       ),
       desc = TextEditingController(text: description),
       amountMissing = amt == null;

  double? get value => parseAmount(amount.text);
  void dispose() {
    amount.dispose();
    desc.dispose();
  }
}

/// Shows detected expenses for review. Nothing is written to the database
/// until the user presses "Save".
class ConfirmExpensesScreen extends StatefulWidget {
  final String rawText;
  final ParseResult result;
  const ConfirmExpensesScreen({
    super.key,
    required this.rawText,
    required this.result,
  });

  @override
  State<ConfirmExpensesScreen> createState() => _ConfirmExpensesScreenState();
}

class _ConfirmExpensesScreenState extends State<ConfirmExpensesScreen> {
  final List<_Draft> _drafts = [];
  DateTime _date = Fmt.dateOnly(DateTime.now());
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    for (final p in widget.result.items) {
      _drafts.add(
        _Draft(
          amt: p.amount,
          description: p.description,
          categoryId: state.categoryByName(p.category).id,
          heard: p.sourceText,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Iterable<_Draft> get _included => _drafts.where((d) => d.include);
  bool get _canSave =>
      _included.isNotEmpty && _included.every((d) => d.value != null);
  double get _total => _included.fold<double>(0, (a, d) => a + (d.value ?? 0));

  void _addBlank() {
    final state = context.read<AppState>();
    setState(
      () => _drafts.add(
        _Draft(
          amt: null,
          description: '',
          categoryId: state.categoryByName('Other').id,
          heard: '(added by you)',
        ),
      ),
    );
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
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final list = <Expense>[
      for (final d in _included)
        Expense(
          amount: d.value!,
          categoryId: d.categoryId,
          description: d.desc.text.trim().isEmpty
              ? (state.categoryById(d.categoryId)?.name ?? 'Expense')
              : d.desc.text.trim(),
          date: _date,
          source: 'voice',
          rawText: widget.rawText,
        ),
    ];
    try {
      await state.expenses.insertMany(list);
      state.changed();
      final total = list.fold<double>(0, (a, e) => a + e.amount);
      nav.popUntil((r) => r.isFirst);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${list.length} expense${list.length == 1 ? '' : 's'} • ${Fmt.money(total)}',
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
    final scheme = Theme.of(context).colorScheme;
    final missing = _included.where((d) => d.value == null).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm expenses')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You said',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(widget.rawText),
                      ],
                    ),
                  ),
                ),
                if (widget.result.items.isEmpty)
                  AppCard(
                    color: scheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'No expenses with amounts were recognised. Go back and correct the text, '
                        'or add an expense below.',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ),
                if (widget.result.ignored.isNotEmpty)
                  AppCard(
                    color: scheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Not understood (not saved): ${widget.result.ignored.join(' • ')}',
                        style: TextStyle(color: scheme.onTertiaryContainer),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Date for all: ${Fmt.date(_date)}'),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _drafts.length; i++) _draftCard(i, scheme),
                TextButton.icon(
                  onPressed: _addBlank,
                  icon: const Icon(Icons.add),
                  label: const Text('Add another expense'),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: scheme.surface,
                boxShadow: const [
                  BoxShadow(blurRadius: 6, color: Colors.black12),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_included.length} expense${_included.length == 1 ? '' : 's'}',
                        ),
                        Text(
                          Fmt.money(_total),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (missing > 0)
                          Text(
                            '$missing need an amount',
                            style: TextStyle(color: scheme.error, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _canSave && !_saving ? _save : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Save'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(130, 52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _draftCard(int i, ColorScheme scheme) {
    final d = _drafts[i];
    final needsAmount = d.include && d.value == null;
    return AppCard(
      color: d.include ? null : scheme.surfaceContainerHighest,
      borderColor: needsAmount ? scheme.error : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: d.include,
                  onChanged: (v) => setState(() => d.include = v ?? true),
                ),
                Expanded(
                  child: Text(
                    'Heard: ${d.heard}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove',
                  onPressed: () => setState(() {
                    _drafts.removeAt(i).dispose();
                  }),
                ),
              ],
            ),
            if (d.include) ...[
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: d.amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Amount (Rs)',
                        errorText: needsAmount
                            ? (d.amountMissing
                                  ? 'Amount not heard: enter it'
                                  : 'Invalid amount')
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: d.desc,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CategoryDropdown(
                value: d.categoryId,
                onChanged: (v) =>
                    setState(() => d.categoryId = v ?? d.categoryId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
