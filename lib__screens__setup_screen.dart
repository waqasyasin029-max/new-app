import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/account_style.dart';
import '../core/app_icons.dart';
import '../core/i18n.dart';
import '../core/pk_accounts.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../services/notification_service.dart';
import '../widgets/lock_gate.dart';

/// Shown once, right after the intro on a fresh install:
/// 1) pick the accounts you really have and how much is in each,
/// 2) offer the app lock.
class FirstSetupScreen extends StatefulWidget {
  const FirstSetupScreen({super.key});

  @override
  State<FirstSetupScreen> createState() => _FirstSetupScreenState();
}

class _FirstSetupScreenState extends State<FirstSetupScreen> {
  int _step = 0;
  bool _busy = false;
  final List<PkAccount> _custom = [];
  final Map<String, TextEditingController> _amounts = {};

  @override
  void initState() {
    super.initState();
    _amounts[PkAccounts.cash.name] = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _on(PkAccount a) => _amounts.containsKey(a.name);

  void _toggle(PkAccount a, bool on) {
    setState(() {
      if (on) {
        _amounts.putIfAbsent(a.name, () => TextEditingController());
      } else {
        _amounts.remove(a.name)?.dispose();
      }
    });
  }

  Future<void> _addOwn() async {
    final name = TextEditingController();
    var type = 'bank';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add another account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: InputDecoration(labelText: tr('Name')),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                borderRadius: BorderRadius.circular(16),
                value: type,
                decoration: InputDecoration(labelText: tr('Type')),
                items: [
                  for (final t in AccountStyle.types)
                    DropdownMenuItem(
                      value: t,
                      child: Text(AccountStyle.label(t)),
                    ),
                ],
                onChanged: (v) => setD(() => type = v ?? type),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    final n = name.text.trim();
    name.dispose();
    if (ok != true || n.isEmpty) return;
    final exists = [
      ...PkAccounts.all,
      ..._custom,
    ].any((a) => a.name.toLowerCase() == n.toLowerCase());
    if (exists) return;
    final a = PkAccount(n, type);
    setState(() => _custom.add(a));
    _toggle(a, true);
  }

  List<PkAccount> get _chosen => [
    for (final a in [...PkAccounts.all, ..._custom])
      if (_on(a)) a,
  ];

  Future<void> _saveAccounts() async {
    final s = context.read<AppState>();
    setState(() => _busy = true);
    final have = (await s.accountRepo.all())
        .map((a) => a.name.toLowerCase())
        .toSet();
    for (final a in _chosen) {
      final c = _amounts[a.name];
      if (c == null || have.contains(a.name.toLowerCase())) continue;
      final v = double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;
      await s.accountRepo.insert(a.name, a.type, v < 0 ? 0 : v);
    }
    await s.reloadAccounts();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = 2;
    });
  }

  bool _remind = true;
  TimeOfDay _remindTime = const TimeOfDay(hour: 22, minute: 0);

  Future<void> _saveReminder() async {
    final s = context.read<AppState>();
    setState(() => _busy = true);
    await s.setReminder(enabled: _remind, time: _remindTime);
    if (_remind) await NotificationService.requestPermission();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = 3;
    });
  }

  Future<void> _turnOnLock() async {
    final s = context.read<AppState>();
    if (!await DeviceLock.available()) {
      if (mounted) {
        snack(
          context,
          'Set a screen lock (PIN, pattern or fingerprint) on your phone first.',
        );
      }
      return;
    }
    final r = await DeviceLock.ask('Turn on app lock');
    if (!mounted) return;
    if (r == DeviceLockResult.ok) {
      await s.setAppLock(true);
      await s.finishSetup();
    }
  }

  Widget _row(PkAccount a, {bool locked = false}) {
    final on = _on(a);
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: locked ? null : () => _toggle(a, !on),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 14, 4),
              child: Row(
                children: [
                  Checkbox(
                    value: on,
                    onChanged: locked ? null : (v) => _toggle(a, v ?? false),
                  ),
                  Icon(AccountStyle.icon(a.type), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a.name,
                      verbatim: a.type != 'cash',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _accountsStep() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              const Text(
                'What do you have?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Tick everything you use to keep or spend money. You can add or change them later.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SectionTitle('Cash'),
              _row(PkAccounts.cash, locked: true),
              const SectionTitle('Digital wallets'),
              for (final a in PkAccounts.wallets) _row(a),
              const SectionTitle('Banks'),
              for (final a in PkAccounts.banks) _row(a),
              if (_custom.isNotEmpty) const SectionTitle('Your own'),
              for (final a in _custom) _row(a),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addOwn,
                icon: const Icon(AppIcons.add, size: 18),
                label: const Text('Add another account'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Next'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _amountsStep() {
    final list = _chosen;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              const Text(
                'How much money is in each?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Write the amount you have right now in every account. Leave it empty if it is zero.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              for (final a in list)
                AppCard(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      Icon(AccountStyle.icon(a.type), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: Text(
                          a.name,
                          verbatim: a.type != 'cash',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: _amounts[a.name],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.end,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '0',
                            prefixText: 'Rs ',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text('Back'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _busy ? null : _saveAccounts,
                    child: const Text('Next'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reminderStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.gradient,
                    ),
                    child: const Icon(
                      AppIcons.bellRinging,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Daily reminder',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  'The app reminds you once a day, at 10 PM, to write down today\'s expenses. You can change the time or turn it off whenever you like, in Settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                TileGroup(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(AppIcons.bellRinging),
                      title: const Text(
                        'Remind me every day',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: _remind,
                      onChanged: (v) => setState(() => _remind = v),
                    ),
                    ListTile(
                      enabled: _remind,
                      leading: const Icon(AppIcons.clock),
                      title: const Text(
                        'Reminder time',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(_remindTime.format(context)),
                      onTap: !_remind
                          ? null
                          : () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: _remindTime,
                              );
                              if (t != null) setState(() => _remindTime = t);
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('Back'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _busy ? null : _saveReminder,
                    child: const Text('Next'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lockStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.gradient,
                  ),
                  child: const Icon(
                    AppIcons.lock,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Lock the app?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ask for your fingerprint or phone PIN every time the app opens, so nobody else can see your money. You can change this in Settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _turnOnLock,
              child: const Text('Turn on app lock'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.read<AppState>().finishSetup(),
            child: const Text('Not now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _step == 0
            ? _accountsStep()
            : _step == 1
            ? _amountsStep()
            : _step == 2
            ? _reminderStep()
            : _lockStep(),
      ),
    );
  }
}
