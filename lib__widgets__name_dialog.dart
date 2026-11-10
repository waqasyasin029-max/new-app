import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Asks for the name shown on Home and saves it. A name is required.
Future<void> askName(BuildContext context) async {
  final state = context.read<AppState>();
  final until = await state.nameLockedUntil();
  if (!context.mounted) return;
  if (until != null) {
    final left = until.difference(DateTime.now());
    final hours = (left.inMinutes / 60).ceil().clamp(1, 24);
    snack(
      context,
      hours <= 1
          ? 'You can change your name only once in 24 hours. Try again in 1 hour.'
          : 'You can change your name only once in 24 hours. Try again in $hours hours.',
    );
    return;
  }
  final c = TextEditingController(text: state.userName);
  final v = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Your name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: c,
            autofocus: true,
            maxLength: 24,
            textCapitalization: TextCapitalization.words,
            decoration:
                InputDecoration(labelText: tr('Name'), counterText: ''),
          ),
          const SizedBox(height: 4),
          Text(
            'You can change it freely for 5 minutes. After that, once every 24 hours.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final t = c.text.trim();
            if (t.isEmpty) {
              snack(ctx, 'Please enter your name.');
              return;
            }
            Navigator.pop(ctx, t);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  c.dispose();
  if (v == null || v == state.userName) return;
  await state.setUserName(v);
  if (context.mounted) snackOk(context, 'Name saved');
}
