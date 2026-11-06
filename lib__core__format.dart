import 'package:intl/intl.dart';

import 'i18n.dart';

class Fmt {
  static final NumberFormat _num = NumberFormat('#,##0.##');
  static String money(num v) => 'Rs ${_num.format(v)}';
  static String number(num v) => _num.format(v);
  static const _urMonths = [
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
  // DateTime.weekday: Monday = 1 ... Sunday = 7
  static const _urDays = [
    'پیر',
    'منگل',
    'بدھ',
    'جمعرات',
    'جمعہ',
    'ہفتہ',
    'اتوار',
  ];

  static String date(DateTime d) => L10n.urdu
      ? '${_urDays[d.weekday - 1]}، ${d.day} ${_urMonths[d.month - 1]} ${d.year}'
      : DateFormat('EEE, d MMM yyyy').format(d);
  static String dayShort(DateTime d) => L10n.urdu
      ? '${d.day} ${_urMonths[d.month - 1]}'
      : DateFormat('d MMM').format(d);
  static String month(DateTime d) => L10n.urdu
      ? '${_urMonths[d.month - 1]} ${d.year}'
      : DateFormat('MMMM yyyy').format(d);
  static String key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
  static DateTime parseKey(String s) => DateTime.parse(s);
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  static DateTime lastOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);
}
