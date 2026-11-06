import 'package:flutter/material.dart' as m;

import 'ur_strings.dart';

/// App language switch. Set by [AppState]; read everywhere through [tr].
class L10n {
  static bool urdu = false;
  static const fallbackFonts = ['NotoNaskhUrdu'];
}

final List<_Template> _templates = [
  for (final e in urTemplates.entries) _Template(e.key, e.value),
];

class _Template {
  final RegExp re;
  final String ur;
  _Template(String english, this.ur)
    : re = RegExp(
        '^${RegExp.escape(english).replaceAll(r'\{\}', '(.*?)')}\$',
        dotAll: true,
      );
}

/// Translates [s] to Urdu when the app language is Urdu. Unknown text is
/// returned unchanged, so user-typed text is never altered.
String tr(String s) {
  if (!L10n.urdu || s.isEmpty) return s;
  final hit = urExact[s];
  if (hit != null) return hit;
  for (final t in _templates) {
    final match = t.re.firstMatch(s);
    if (match != null) {
      var out = t.ur;
      for (var i = 1; i <= match.groupCount; i++) {
        out = out.replaceAll('{${i - 1}}', tr(match.group(i) ?? ''));
      }
      return out;
    }
  }
  return s;
}

/// Drop-in replacement for Flutter's [m.Text] that translates its text.
/// Screens import this and hide Flutter's Text.
class Text extends m.StatelessWidget {
  final String data;
  final m.TextStyle? style;
  final int? maxLines;
  final m.TextOverflow? overflow;
  final m.TextAlign? textAlign;
  final bool? softWrap;

  /// True for text typed by the user (descriptions, notes): never translated.
  final bool verbatim;

  const Text(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
    this.verbatim = false,
  });

  @override
  m.Widget build(m.BuildContext context) => m.Text(
    verbatim ? data : tr(data),
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    textAlign: textAlign,
    softWrap: softWrap,
  );
}
