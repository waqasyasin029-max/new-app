import 'expense_parser.dart';

/// Urdu phrases for the talking assistant (read out by text-to-speech, so
/// everything is written in Urdu script and numbers are spelled out).
class UrduSpeech {
  static const _t = [
    'صفر',
    'ایک',
    'دو',
    'تین',
    'چار',
    'پانچ',
    'چھ',
    'سات',
    'آٹھ',
    'نو',
    'دس',
    'گیارہ',
    'بارہ',
    'تیرہ',
    'چودہ',
    'پندرہ',
    'سولہ',
    'سترہ',
    'اٹھارہ',
    'انیس',
    'بیس',
    'اکیس',
    'بائیس',
    'تئیس',
    'چوبیس',
    'پچیس',
    'چھبیس',
    'ستائیس',
    'اٹھائیس',
    'انتیس',
    'تیس',
    'اکتیس',
    'بتیس',
    'تینتیس',
    'چونتیس',
    'پینتیس',
    'چھتیس',
    'سینتیس',
    'اڑتیس',
    'انتالیس',
    'چالیس',
    'اکتالیس',
    'بیالیس',
    'تینتالیس',
    'چوالیس',
    'پینتالیس',
    'چھیالیس',
    'سینتالیس',
    'اڑتالیس',
    'انچاس',
    'پچاس',
    'اکیاون',
    'باون',
    'ترپن',
    'چون',
    'پچپن',
    'چھپن',
    'ستاون',
    'اٹھاون',
    'انسٹھ',
    'ساٹھ',
    'اکسٹھ',
    'باسٹھ',
    'تریسٹھ',
    'چونسٹھ',
    'پینسٹھ',
    'چھیاسٹھ',
    'سڑسٹھ',
    'اڑسٹھ',
    'انہتر',
    'ستر',
    'اکہتر',
    'بہتر',
    'تہتر',
    'چوہتر',
    'پچھتر',
    'چھہتر',
    'ستتر',
    'اٹھہتر',
    'اناسی',
    'اسی',
    'اکیاسی',
    'بیاسی',
    'تراسی',
    'چوراسی',
    'پچاسی',
    'چھیاسی',
    'ستاسی',
    'اٹھاسی',
    'نواسی',
    'نوے',
    'اکانوے',
    'بانوے',
    'ترانوے',
    'چورانوے',
    'پچانوے',
    'چھیانوے',
    'ستانوے',
    'اٹھانوے',
    'ننانوے',
  ];

  static const _months = [
    'جنوری',
    'فروری',
    'مارچ',
    'اپریل',
    'مئی',
    'جون',
    'جولائی',
    'اگست',
    'ستمبر',
    'اکتوبر',
    'نومبر',
    'دسمبر',
  ];
  static const _days = [
    'پیر',
    'منگل',
    'بدھ',
    'جمعرات',
    'جمعہ',
    'ہفتہ',
    'اتوار',
  ];

  /// 1250 -> "ایک ہزار دو سو پچاس".
  static String number(int n) {
    if (n < 0) return 'منفی ${number(-n)}';
    if (n < 100) return _t[n];
    String part(int div, String unit) {
      final q = n ~/ div, r = n % div;
      return '${number(q)} $unit${r > 0 ? ' ${number(r)}' : ''}';
    }

    if (n < 1000) return part(100, 'سو');
    if (n < 100000) return part(1000, 'ہزار');
    if (n < 10000000) return part(100000, 'لاکھ');
    return part(10000000, 'کروڑ');
  }

  static String money(double amount) {
    final whole = amount.floor();
    final paisa = ((amount - whole) * 100).round();
    final w = '${number(whole)} روپے';
    return paisa > 0 ? '$w اور ${number(paisa)} پیسے' : w;
  }

  static String dayPart(int hour) {
    if (hour >= 5 && hour < 12) return 'صبح';
    if (hour >= 12 && hour < 16) return 'دوپہر';
    if (hour >= 16 && hour < 19) return 'شام';
    return 'رات';
  }

  static String timeWords(DateTime d) {
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final part = dayPart(d.hour);
    if (d.minute == 0) return '$part کے ${number(h12)} بجے ہیں';
    return '$part کے ${number(h12)} بج کر ${number(d.minute)} منٹ ہوئے ہیں';
  }

  static String dateWords(DateTime d) =>
      '${_days[d.weekday - 1]}، ${number(d.day)} ${_months[d.month - 1]}';

  /// Greeting like a waiter: salam, name, date, time, then the first question.
  static String greeting(String name, DateTime now) {
    final who = name.trim().isEmpty ? '' : ' ${name.trim()} سر';
    return 'السلام علیکم$who! آج ${dateWords(now)} ہے، اور ${timeWords(now)}۔ '
        'بتائیے، اب کتنا خرچہ ہوا؟';
  }

  static String _itemName(ParsedExpense e, String Function(String) tr) {
    final arabic = RegExp(r'[؀-ۿ]');
    if (arabic.hasMatch(e.description)) return e.description;
    return tr(e.category);
  }

  /// "آپ نے بتایا: چائے کے دو سو روپے، پیٹرول کے تین سو روپے۔ کل پانچ سو روپے۔"
  /// [accountNames] (one per item, already in Urdu) adds where each was paid from.
  static String repeatOrder(
    ParseResult r,
    String Function(String) tr, {
    List<String?>? accountNames,
  }) {
    final names = accountNames;
    final allSame =
        names != null &&
        names.isNotEmpty &&
        names.every((n) => n != null && n == names.first);
    final parts = <String>[];
    for (var i = 0; i < r.items.length; i++) {
      final e = r.items[i];
      final acc = (names != null && !allSame && names[i] != null)
          ? ' ${names[i]} سے'
          : '';
      parts.add('${_itemName(e, tr)} کے ${money(e.amount ?? 0)}$acc');
    }
    final total = r.items.length > 1 ? ' کل ${money(r.total)}۔' : '';
    final paid = allSame ? ' ${names.first} سے ادا ہوئے۔' : '';
    return 'آپ نے بتایا: ${parts.join('، ')}۔$total$paid';
  }

  static const _yes = {
    'جی',
    'ہاں',
    'ہان',
    'ٹھیک',
    'صحیح',
    'درست',
    'اوکے',
    'بالکل',
    'کرو',
    'محفوظ',
    'سیو',
    'پکا',
    'yes',
    'yeah',
    'ok',
    'okay',
    'haan',
    'han',
    'ji',
    'jee',
    'theek',
    'thik',
    'sahi',
    'bilkul',
    'done',
    'save',
    'kardo',
    'pakka',
  };
  static const _no = {
    'نہیں',
    'نہی',
    'نہ',
    'غلط',
    'no',
    'nahi',
    'nahin',
    'nai',
    'galat',
    'nope',
  };

  static List<String> _tokens(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[،۔؟!?,.\-"]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  static bool saysYes(String text) => _tokens(text).any(_yes.contains);
  static bool saysNo(String text) => _tokens(text).any(_no.contains);

  /// Classifies the answer to "کیا یہ ٹھیک ہے؟".
  static Reply classify(String text) {
    final tokens = _tokens(text);
    if (tokens.any(_no.contains)) return Reply.no;
    if (tokens.length <= 5 && tokens.any(_yes.contains)) return Reply.yes;
    return Reply.other;
  }

  /// Turns digits inside a sentence into Urdu words so text-to-speech reads
  /// them correctly: "300 روپے" -> "تین سو روپے".
  static String spokenDigits(String text) {
    return text.replaceAllMapped(RegExp(r'\d[\d,]*(?:\.\d+)?'), (m) {
      final raw = m[0]!.replaceAll(',', '');
      final dot = raw.indexOf('.');
      final whole = int.tryParse(dot < 0 ? raw : raw.substring(0, dot));
      if (whole == null || whole > 999999999) return m[0]!;
      if (dot < 0) return number(whole);
      final frac = raw
          .substring(dot + 1)
          .split('')
          .map((d) => _t[int.parse(d)])
          .join(' ');
      return '${number(whole)} اعشاریہ $frac';
    });
  }
}

enum Reply { yes, no, other }
