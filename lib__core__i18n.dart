import 'package:flutter/material.dart' as m;

import 'ur_strings.dart';

/// App language switch. Set by [AppState]; read everywhere through [tr].
class L10n {
  static bool urdu = false;
  static const fallbackFonts = ['NotoNastaliqUrdu'];
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
String tr(String s) => L10n.urdu ? trUr(s) : s;

/// Always translates to Urdu, whatever the app language is (used by the
/// intro pages, which are shown in Urdu to everyone).
String trUr(String s) {
  if (s.isEmpty) return s;
  final hit = urExact[s];
  if (hit != null) return hit;
  for (final t in _templates) {
    final match = t.re.firstMatch(s);
    if (match != null) {
      var out = t.ur;
      for (var i = 1; i <= match.groupCount; i++) {
        out = out.replaceAll('{${i - 1}}', trUr(match.group(i) ?? ''));
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

  /// True to always show the Urdu translation, even in English mode.
  final bool urdu;

  const Text(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
    this.verbatim = false,
    this.urdu = false,
  });

  static final _arabicScript = RegExp(r'[\u0600-\u06FF]');

  @override
  m.Widget build(m.BuildContext context) {
    final out = verbatim ? data : (urdu ? trUr(data) : tr(data));
    var st = style;
    final fs = st?.fontSize;
    // Nastaliq looks larger than English at the same size: headings in Urdu
    // are drawn 4 px smaller (digits and English stay as they are).
    if ((L10n.urdu || urdu) &&
        fs != null &&
        fs >= 17 &&
        _arabicScript.hasMatch(out)) {
      st = st!.copyWith(fontSize: fs - 4);
    }
    return m.Text(
      out,
      style: st,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
    );
  }
}
