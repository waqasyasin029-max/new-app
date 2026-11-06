import 'lexicon.dart';
import 'number_words.dart';

/// One expense detected in a spoken sentence. [amount] is null when no amount
/// could be recognised: the app never guesses an amount.
class ParsedExpense {
  final double? amount;
  final String description;
  final String category;
  final String sourceText;
  const ParsedExpense({
    required this.amount,
    required this.description,
    required this.category,
    required this.sourceText,
  });
}

class ParseResult {
  final List<ParsedExpense> items;
  final List<String> ignored;
  const ParseResult(this.items, this.ignored);
  double get total => items.fold(0.0, (s, e) => s + (e.amount ?? 0));
  int get missingAmounts => items.where((e) => e.amount == null).length;
}

enum _Kind { word, num, sep }

class _Tok {
  final _Kind kind;
  final String text;
  final double value;
  final bool strong;
  bool isAmount = false;
  _Tok.word(this.text) : kind = _Kind.word, value = 0, strong = false;
  _Tok.sep(this.text) : kind = _Kind.sep, value = 0, strong = false;
  _Tok.num(this.value, this.text, {this.strong = false}) : kind = _Kind.num;
}

class _NumAcc {
  double total = 0, current = 0;
  bool has = false, lastMult = false, strong = false, pendingHalf = false;
  double? lastSmall;

  double get value => ((total + current) * 100).round() / 100;

  bool consume(_Tok t) {
    if (t.kind == _Kind.num) {
      if (has && !lastMult) return false;
      current += t.value;
      has = true;
      lastMult = false;
      lastSmall = null;
      if (t.strong || t.value >= 10) strong = true;
      return true;
    }
    if (t.kind != _Kind.word) return false;
    final w = NumberWords.classify(t.text, hasValue: has);
    switch (w.kind) {
      case NwKind.none:
        return false;
      case NwKind.small:
        if (has && !lastMult) {
          final ok =
              lastSmall != null &&
              lastSmall! >= 20 &&
              lastSmall! % 10 == 0 &&
              w.value >= 1 &&
              w.value <= 9;
          if (!ok) return false;
        }
        current += w.value + (pendingHalf ? 0.5 : 0);
        pendingHalf = false;
        has = true;
        lastMult = false;
        lastSmall = w.value;
        if (w.value >= 10) strong = true;
        return true;
      case NwKind.fraction:
        if (has && !lastMult) return false;
        current += w.value;
        has = true;
        lastMult = false;
        lastSmall = null;
        return true;
      case NwKind.half:
        if (has && !lastMult) return false;
        pendingHalf = true;
        has = true;
        lastMult = true;
        return true;
      case NwKind.mult:
        if (!has) {
          if (!w.aloneOk) return false;
          current = 1;
          has = true;
        }
        final base = current == 0 ? 1.0 : current;
        if (w.value == 100) {
          current = base * 100;
        } else {
          total += base * w.value;
          current = 0;
        }
        lastMult = true;
        lastSmall = null;
        strong = true;
        return true;
    }
  }
}

/// Turns free speech/text (English, Roman Urdu, Urdu) into separate expenses.
class ExpenseParser {
  static ParseResult parse(String input) {
    var toks = _tokenize(_normalize(input));
    toks = _mergeNumbers(toks);
    _markAmounts(toks);

    final items = <ParsedExpense>[];
    final ignored = <String>[];
    for (final chunk in _chunks(toks)) {
      for (final seg in _splitByAmounts(chunk)) {
        final item = _build(seg);
        if (item != null) {
          items.add(item);
        } else {
          final leftover = seg
              .where((t) => t.kind == _Kind.word && !Lexicon.isStop(t.text))
              .map((t) => t.text)
              .join(' ');
          if (leftover.isNotEmpty) ignored.add(leftover);
        }
      }
    }
    return ParseResult(items, ignored);
  }

  static String _normalize(String s) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const extended = '۰۱۲۳۴۵۶۷۸۹';
    final sb = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final ch = String.fromCharCode(r);
      var i = arabicIndic.indexOf(ch);
      if (i < 0) i = extended.indexOf(ch);
      sb.write(i >= 0 ? '$i' : ch);
    }
    var t = sb.toString();
    t = t
        .replaceAll('،', ',')
        .replaceAll('۔', '.')
        .replaceAll('؟', '?')
        .replaceAll('٫', '.');
    t = t.replaceAll(RegExp(r'(?<=\d),(?=\d{3}(?!\d))'), '');
    t = t.replaceAllMapped(RegExp(r'\b(rs|pkr)\.'), (m) => m[1]!);
    return t;
  }

  static List<_Tok> _tokenize(String text) {
    final re = RegExp(
      r"(\d+(?:\.\d+)?)(k)\b|(\d+(?:\.\d+)?)|([a-z\u0600-\u06FF\u200c']+)|([,;.!?\n]+)",
    );
    final toks = <_Tok>[];
    for (final m in re.allMatches(text)) {
      if (m.group(1) != null) {
        toks.add(
          _Tok.num(double.parse(m.group(1)!) * 1000, m.group(0)!, strong: true),
        );
      } else if (m.group(3) != null) {
        toks.add(_Tok.num(double.parse(m.group(3)!), m.group(3)!));
      } else if (m.group(4) != null) {
        toks.add(_Tok.word(m.group(4)!));
      } else {
        toks.add(_Tok.sep(m.group(5)!));
      }
    }
    return toks;
  }

  static List<_Tok> _mergeNumbers(List<_Tok> toks) {
    final out = <_Tok>[];
    var i = 0;
    while (i < toks.length) {
      final t = toks[i];
      final starts =
          t.kind == _Kind.num ||
          (t.kind == _Kind.word && NumberWords.isStarter(t.text));
      if (!starts) {
        out.add(t);
        i++;
        continue;
      }
      final acc = _NumAcc();
      var j = i;
      while (j < toks.length && acc.consume(toks[j])) {
        j++;
      }
      if (j == i) {
        out.add(t);
        i++;
        continue;
      }
      out.add(
        _Tok.num(
          acc.value,
          toks.sublist(i, j).map((e) => e.text).join(' '),
          strong: acc.strong,
        ),
      );
      i = j;
    }
    return out;
  }

  /// A number is an amount when it is big/explicit, or sits next to a currency
  /// word or "ka/ki/ke". Small numbers otherwise are quantities ("2 samosay").
  static void _markAmounts(List<_Tok> toks) {
    for (var k = 0; k < toks.length; k++) {
      final t = toks[k];
      if (t.kind != _Kind.num) continue;
      final prev = k > 0 ? toks[k - 1] : null;
      final next = k + 1 < toks.length ? toks[k + 1] : null;
      final prevCur =
          prev != null &&
          prev.kind == _Kind.word &&
          Lexicon.currency.contains(prev.text);
      final nextCur =
          next != null &&
          next.kind == _Kind.word &&
          (Lexicon.currency.contains(next.text) ||
              Lexicon.postpositions.contains(next.text));
      final nextUnit =
          next != null &&
          next.kind == _Kind.word &&
          Lexicon.units.contains(next.text);
      final near = prevCur || nextCur;
      t.isAmount =
          t.value > 0 && (near || ((t.strong || t.value >= 10) && !nextUnit));
    }
  }

  static List<List<_Tok>> _chunks(List<_Tok> toks) {
    final chunks = <List<_Tok>>[];
    var cur = <_Tok>[];
    for (final t in toks) {
      if (t.kind == _Kind.sep) {
        if (cur.isNotEmpty) chunks.add(cur);
        cur = <_Tok>[];
      } else {
        cur.add(t);
      }
    }
    if (cur.isNotEmpty) chunks.add(cur);
    return chunks;
  }

  static bool _isCurrency(_Tok t) =>
      t.kind == _Kind.word && Lexicon.currency.contains(t.text);
  static bool _isPostposition(_Tok t) =>
      t.kind == _Kind.word && Lexicon.postpositions.contains(t.text);

  /// Splits one comma-free chunk that contains several amounts, e.g.
  /// "300 petrol 200 chai" (amount first) or "petrol 300 chai 200" (item first).
  static List<List<_Tok>> _splitByAmounts(List<_Tok> chunk) {
    final idx = <int>[
      for (var i = 0; i < chunk.length; i++)
        if (chunk[i].kind == _Kind.num && chunk[i].isAmount) i,
    ];
    if (idx.length < 2) return [chunk];

    final leading = chunk.sublist(0, idx.first).where((t) {
      if (t.kind == _Kind.num) return t.value >= 2;
      return !Lexicon.isStop(t.text) && !Lexicon.currency.contains(t.text);
    }).length;

    final parts = <List<_Tok>>[];
    var start = 0;
    for (var n = 1; n < idx.length; n++) {
      int boundary;
      if (leading > 0) {
        // item-first: close the previous part after its amount (+ "rupay", "ki")
        boundary = idx[n - 1] + 1;
        while (boundary < idx[n] &&
            (_isCurrency(chunk[boundary]) ||
                _isPostposition(chunk[boundary]))) {
          boundary++;
        }
      } else {
        // amount-first: start the next part at its amount (or its "rs" prefix)
        boundary = idx[n];
        while (boundary - 1 > idx[n - 1] && _isCurrency(chunk[boundary - 1])) {
          boundary--;
        }
      }
      parts.add(chunk.sublist(start, boundary));
      start = boundary;
    }
    parts.add(chunk.sublist(start));
    return parts;
  }

  static String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static ParsedExpense? _build(List<_Tok> seg) {
    _Tok? amt;
    for (final t in seg) {
      if (t.kind == _Kind.num && t.isAmount) {
        amt = t;
        break;
      }
    }
    final words = [
      for (final t in seg)
        if (t.kind == _Kind.word) t.text,
    ];
    final cat = Lexicon.categorize(words);
    if (amt == null && cat == null) return null;

    final parts = <String>[];
    for (final t in seg) {
      if (t.kind == _Kind.num) {
        if (!identical(t, amt) && t.value >= 2) parts.add(_fmtQty(t.value));
        continue;
      }
      if (Lexicon.isStop(t.text) || Lexicon.currency.contains(t.text)) continue;
      parts.add(t.text);
    }
    var desc = parts.join(' ').trim();
    if (desc.isEmpty) {
      desc = cat ?? 'Expense';
    } else {
      desc = desc[0].toUpperCase() + desc.substring(1);
    }
    return ParsedExpense(
      amount: amt?.value,
      description: desc,
      category: cat ?? 'Other',
      sourceText: seg.map((t) => t.text).join(' '),
    );
  }
}
