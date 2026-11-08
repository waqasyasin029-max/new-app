import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../state/app_state.dart';
import 'common.dart';

/// Asks for the name shown on Home and saves it. An empty name removes it.
Future<void> askName(BuildContext context) async {
  final state = context.read<AppState>();
  final c = TextEditingController(text: state.userName);
  final v = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLength: 24,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: tr('Name'), counterText: ''),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  c.dispose();
  if (v == null) return;
  await state.setUserName(v);
  if (context.mounted) {
    snackOk(context, v.isEmpty ? 'Name removed' : 'Name saved');
  }
}
