import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../core/i18n.dart';

/// Loads data and automatically reloads when stored data changes
/// ([AppState.revision]) or when [depends] changes (filters, month, ...).
class DataLoader<T> extends StatefulWidget {
  final Future<T> Function(AppState state) load;
  final Widget Function(BuildContext context, T data) builder;
  final Object? depends;
  const DataLoader({
    super.key,
    required this.load,
    required this.builder,
    this.depends,
  });

  @override
  State<DataLoader<T>> createState() => _DataLoaderState<T>();
}

class _DataLoaderState<T> extends State<DataLoader<T>> {
  Future<T>? _future;
  int _rev = -1;
  Object? _dep;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_future == null || _rev != state.revision || _dep != widget.depends) {
      _rev = state.revision;
      _dep = widget.depends;
      _future = widget.load(state);
    }
    return FutureBuilder<T>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: ${snap.error}'),
            ),
          );
        }
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        return widget.builder(ctx, snap.data as T);
      },
    );
  }
}
