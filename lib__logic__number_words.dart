/// Number-word support for English, Roman Urdu and Urdu script.
enum NwKind { none, small, fraction, half, mult }

class Nw {
  final NwKind kind;
  final double value;
  final bool aloneOk;
  const Nw(this.kind, [this.value = 0, this.aloneOk = false]);
}

class NumberWords {
  static const Map<String, double> _small = {
    'zero': 0,
    'sifar': 0,
    'ek': 1,
    'aik': 1,
    'one': 1,
    'ایک': 1,
    'do': 2,
    'two': 2,
    'دو': 2,
    'teen': 3,
    'tin': 3,
    'three': 3,
    'تین': 3,
    'char': 4,
    'chaar': 4,
    'four': 4,
    'چار': 4,
    'paanch': 5,
    'panch': 5,
    'five': 5,
    'پانچ': 5,
    'chhe': 6,
    'che': 6,
    'chhay': 6,
    'chey': 6,
    'six': 6,
    'چھ': 6,
    'saat': 7,
    'seven': 7,
    'سات': 7,
    'aath': 8,
    'ath': 8,
    'eight': 8,
    'آٹھ': 8,
    'nau': 9,
    'nao': 9,
    'nine': 9,
    'نو': 9,
    'das': 10,
    'ten': 10,
    'دس': 10,
    'gyarah': 11,
    'giarah': 11,
    'eleven': 11,
    'گیارہ': 11,
    'barah': 12,
    'baarah': 12,
    'twelve': 12,
    'بارہ': 12,
    'terah': 13,
    'thirteen': 13,
    'تیرہ': 13,
    'chaudah': 14,
    'chaudha': 14,
    'fourteen': 14,
    'چودہ': 14,
    'pandrah': 15,
    'pandra': 15,
    'fifteen': 15,
    'پندرہ': 15,
    'solah': 16,
    'sixteen': 16,
    'سولہ': 16,
    'satrah': 17,
    'seventeen': 17,
    'سترہ': 17,
    'atharah': 18,
    'eighteen': 18,
    'اٹھارہ': 18,
    'unnees': 19,
    'unnis': 19,
    'nineteen': 19,
    'انیس': 19,
    'bees': 20,
    'bis': 20,
    'twenty': 20,
    'بیس': 20,
    'pachees': 25,
    'pachis': 25,
    'پچیس': 25,
    'tees': 30,
    'tis': 30,
    'thirty': 30,
    'تیس': 30,
    'chalees': 40,
    'chalis': 40,
    'forty': 40,
    'چالیس': 40,
    'pachas': 50,
    'pachaas': 50,
    'fifty': 50,
    'پچاس': 50,
    'sixty': 60,
    'ساٹھ': 60,
    'sattar': 70,
    'seventy': 70,
    'ستر': 70,
    'pachattar': 75,
    'پچھتر': 75,
    'assi': 80,
    'eighty': 80,
    'اسی': 80,
    'nabbe': 90,
    'nabbay': 90,
    'ninety': 90,
    'نوے': 90,
  };

  static const Map<String, double> _fraction = {
    'dedh': 1.5,
    'derh': 1.5,
    'ڈیڑھ': 1.5,
    'dhai': 2.5,
    'dhaai': 2.5,
    'ڈھائی': 2.5,
    'sawa': 1.25,
    'سوا': 1.25,
  };

  static const Set<String> _half = {'sadhe', 'sade', 'ساڑھے'};
  static const Set<String> _hundred = {'sau', 'hundred', 'سو'};
  static const Set<String> _thousand = {
    'hazar',
    'hazaar',
    'hajar',
    'thousand',
    'ہزار',
  };
  static const Set<String> _lakh = {'lakh', 'lac', 'lakhs', 'lacs', 'لاکھ'};

  /// 'so' only counts as "hundred" when it follows a number ("teen so").
  static const String _ambiguousHundred = 'so';

  static Nw classify(String w, {required bool hasValue}) {
    final s = _small[w];
    if (s != null) return Nw(NwKind.small, s);
    final f = _fraction[w];
    if (f != null) return Nw(NwKind.fraction, f);
    if (_half.contains(w)) return const Nw(NwKind.half);
    if (_hundred.contains(w)) return const Nw(NwKind.mult, 100, true);
    if (w == _ambiguousHundred) {
      return hasValue
          ? const Nw(NwKind.mult, 100, false)
          : const Nw(NwKind.none);
    }
    if (_thousand.contains(w)) return const Nw(NwKind.mult, 1000, true);
    if (_lakh.contains(w)) return const Nw(NwKind.mult, 100000, true);
    return const Nw(NwKind.none);
  }

  static bool isStarter(String w) =>
      w != _ambiguousHundred &&
      classify(w, hasValue: false).kind != NwKind.none;
}
