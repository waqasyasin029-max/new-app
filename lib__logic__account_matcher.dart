/// Finds which account a spoken sentence refers to ("200 ki chai jazzcash se").
/// Returns null when nothing (or more than one account) is mentioned: the app
/// then asks you instead of guessing.
class AccountMatcher {
  static const Map<String, List<String>> _builtin = {
    'cash': ['cash', 'کیش', 'نقد', 'naqd'],
    'jazzcash': [
      'jazzcash',
      'jazz cash',
      'jaz cash',
      'jazz',
      'جیز کیش',
      'جاز کیش',
      'جیز',
    ],
    'easypaisa': [
      'easypaisa',
      'easy paisa',
      'easy paise',
      'easypesa',
      'ایزی پیسہ',
      'ایزی پیسا',
      'ایزی پیسے',
    ],
    'nayapay': ['nayapay', 'naya pay', 'naya pe', 'نیا پے', 'نیاپے', 'نیا پے'],
    'meezan': ['meezan bank', 'meezan', 'mezan', 'میزان بینک', 'میزان'],
  };

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9؀-ۿ‌ ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Set<String> aliasesFor(String accountName) {
    final n = _norm(accountName);
    final squashed = n.replaceAll(' ', '');
    final out = <String>{
      if (n.isNotEmpty) n,
      if (squashed.isNotEmpty) squashed,
    };
    _builtin.forEach((key, list) {
      if (squashed.contains(key)) out.addAll(list.map(_norm));
    });
    return out;
  }

  /// Account ids mentioned in [text] (longest alias wins, so "jazz cash" is not also "cash").
  static Set<int> mentioned(
    String text,
    List<({int id, String name})> accounts,
  ) {
    var rest = ' ${_norm(text)} ';
    final pairs = <(String, int)>[];
    for (final a in accounts) {
      for (final al in aliasesFor(a.name)) {
        pairs.add((al, a.id));
      }
    }
    pairs.sort((x, y) => y.$1.length.compareTo(x.$1.length));
    final found = <int>{};
    for (final p in pairs) {
      final needle = ' ${p.$1} ';
      if (rest.contains(needle)) {
        found.add(p.$2);
        rest = rest.replaceAll(needle, ' ');
      }
    }
    return found;
  }

  static int? match(String text, List<({int id, String name})> accounts) {
    final f = mentioned(text, accounts);
    return f.length == 1 ? f.first : null;
  }

  /// Removes the account words (and a following "se") from a description.
  static String strip(String text, List<({int id, String name})> accounts) {
    var t = ' ${_norm(text)} ';
    final als = <String>{
      for (final a in accounts) ...aliasesFor(a.name),
    }.toList()..sort((x, y) => y.length.compareTo(x.length));
    for (final al in als) {
      t = t.replaceAll(' $al se ', ' ').replaceAll(' $al ', ' ');
    }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
