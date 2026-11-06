import 'package:intl/intl.dart';

class Fmt {
  static final NumberFormat _num = NumberFormat('#,##0.##');
  static String money(num v) => 'Rs ${_num.format(v)}';
  static String number(num v) => _num.format(v);
  static String date(DateTime d) => DateFormat('EEE, d MMM yyyy').format(d);
  static String dayShort(DateTime d) => DateFormat('d MMM').format(d);
  static String month(DateTime d) => DateFormat('MMMM yyyy').format(d);
  static String key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
  static DateTime parseKey(String s) => DateTime.parse(s);
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  static DateTime lastOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);
}
