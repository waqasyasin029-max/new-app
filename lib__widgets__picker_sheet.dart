import 'package:flutter/material.dart' hide Text;

import '../core/app_icons.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

/// One row in [PickerField]'s bottom sheet.
class PickerOption<T> {
  final T value;
  final String label;
  final Widget? leading;

  /// Optional small grey line under the label (bottom sheet only).
  final String? subtitle;

  /// True for text typed by the user (account names): never translated.
  final bool verbatim;
  const PickerOption({
    required this.value,
    required this.label,
    this.leading,
    this.subtitle,
    this.verbatim = false,
  });
}

/// Opens the same themed sheet without a form field. Returns null when the
/// person closes it without choosing.
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<PickerOption<T>> options,
  required T selected,
}) async {
  final r = await showModalBottomSheet<_Picked<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        _PickerSheet<T>(title: title, options: options, selected: selected),
  );
  return r?.value;
}

class _Picked<T> {
  final T value;
  const _Picked(this.value);
}

/// A form field that opens a themed bottom sheet instead of the default
/// Material dropdown. Used for categories and accounts.
class PickerField<T> extends StatelessWidget {
  final String label;
  final String? errorText;
  final T value;
  final List<PickerOption<T>> options;
  final ValueChanged<T> onChanged;
  final String sheetTitle;
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.errorText,
    String? sheetTitle,
  }) : sheetTitle = sheetTitle ?? label;

  PickerOption<T>? get _current {
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final r = await showModalBottomSheet<_Picked<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PickerSheet<T>(
        title: sheetTitle,
        options: options,
        selected: value,
      ),
    );
    if (r != null) onChanged(r.value);
  }

  @override
  Widget build(BuildContext context) {
    final cur = _current;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _open(context),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: tr(label),
          errorText: errorText == null ? null : tr(errorText!),
          suffixIcon: const RotatedBox(
            quarterTurns: 1,
            child: Icon(AppIcons.chevronRight, size: 20),
          ),
        ),
        child: cur == null
            ? const SizedBox(height: 24)
            : Row(
                children: [
                  if (cur.leading != null) ...[
                    cur.leading!,
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      cur.label,
                      verbatim: cur.verbatim,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PickerSheet<T> extends StatelessWidget {
  final String title;
  final List<PickerOption<T>> options;
  final T selected;
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.65;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 0, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Material(
                  color: AppColors.fieldFill,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(AppIcons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final o in options)
                  _row(context, o, o.value == selected),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, PickerOption<T> o, bool on) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: on ? AppColors.primary.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context, _Picked<T>(o.value)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (o.leading != null) ...[
                  o.leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.label,
                        verbatim: o.verbatim,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: on ? FontWeight.w800 : FontWeight.w700,
                        ),
                      ),
                      if (o.subtitle != null)
                        Text(
                          o.subtitle!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: on ? AppColors.primary : AppColors.line,
                      width: 2,
                    ),
                  ),
                  child: on
                      ? Center(
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
