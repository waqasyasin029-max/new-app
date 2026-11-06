// Run with:  dart run tool/account_check.dart
import 'dart:io';

import '../lib/logic/account_matcher.dart';

const accs = <({int id, String name})>[
  (id: 1, name: 'Cash'),
  (id: 2, name: 'JazzCash'),
  (id: 3, name: 'Naya Pay'),
  (id: 4, name: 'Easypaisa'),
  (id: 5, name: 'Meezan Bank'),
];
int failures = 0;
void t(String text, int? want) {
  final got = AccountMatcher.match(text, accs);
  if (got != want) {
    failures++;
    stdout.writeln('FAIL  "$text" want=$want got=$got');
  } else {
    stdout.writeln('PASS  "$text" -> $got');
  }
}

void main() {
  t('200 ki chai jazzcash se', 2);
  t('200 ki chai jazz cash se', 2);
  t('300 petrol cash se', 1);
  t('500 grocery easypaisa se', 4);
  t('bijli bill meezan bank se 2000', 5);
  t('naya pay se 150 rickshaw', 3);
  t('نیا پے سے دو سو کی چائے', 3);
  t('دو سو کی چائے جیز کیش سے', 2);
  t('200 ki chai', null);
  t('200 jazzcash se aur 100 cash se', null);
  t('jazzcash se 200 ki chai', 2);
  final s = AccountMatcher.strip('chai jazz cash se', accs);
  if (s != 'chai') {
    failures++;
    stdout.writeln('FAIL strip got "$s"');
  } else {
    stdout.writeln('PASS strip');
  }
  stdout.writeln(failures == 0 ? '\nALL PASSED' : '\n$failures FAILED');
  exit(failures == 0 ? 0 : 1);
}
