// Run with:  dart run tool/parser_check.dart
import 'dart:io';

import '../lib/logic/expense_parser.dart';

int failures = 0;

void check(
  String name,
  String input,
  List<(double?, String)> expected, {
  List<String>? ignored,
}) {
  final r = ExpenseParser.parse(input);
  final got = [for (final i in r.items) (i.amount, i.category)];
  var ok = got.length == expected.length;
  if (ok) {
    for (var i = 0; i < got.length; i++) {
      if (got[i] != expected[i]) ok = false;
    }
  }
  if (ignored != null && r.ignored.join('|') != ignored.join('|')) ok = false;
  if (!ok) {
    failures++;
    stdout.writeln(
      'FAIL  $name\n   input:    $input\n   expected: $expected\n   got:      $got  ignored=${r.ignored}',
    );
  } else {
    stdout.writeln(
      'PASS  $name   -> ${r.items.map((e) => "${e.amount} ${e.category} [${e.description}]").join("; ")}',
    );
  }
}

void main() {
  const four = <(double?, String)>[
    (300, 'Transport'),
    (200, 'Food'),
    (500, 'Groceries'),
    (150, 'Transport'),
  ];
  check(
    'user example (commas)',
    'Aj 300 rupay petrol ka kharcha hua, 200 ki chai pi, 500 ki grocery ki aur 150 rupay rickshaw ka kiraya diya.',
    four,
  );
  check(
    'user example (no punctuation)',
    'aj 300 rupay petrol ka kharcha hua 200 ki chai pi 500 ki grocery ki aur 150 rupay rickshaw ka kiraya diya',
    four,
  );
  check(
    'Urdu script',
    'آج تین سو روپے پیٹرول، دو سو کی چائے، پانچ سو کی گروسری اور ڈیڑھ سو روپے رکشہ کا کرایہ',
    four,
  );
  check('Urdu digits', '۳۰۰ روپے پیٹرول ۲۰۰ کی چائے', [
    (300, 'Transport'),
    (200, 'Food'),
  ]);
  check(
    'roman number words',
    'teen sau pachas rupay ka khana, do hazar paanch sau bijli ka bill',
    [(350, 'Food'), (2500, 'Bills')],
  );
  check(
    'english k suffix',
    'I spent 2k on groceries and 450 for dinner and 1.5k fuel',
    [(2000, 'Groceries'), (450, 'Food'), (1500, 'Transport')],
  );
  check('missing amount is NOT invented', 'chai pi, 200 ki grocery', [
    (null, 'Food'),
    (200, 'Groceries'),
  ]);
  check('quantities, item-first', '2 samosay 100 rupay ke aur 5 chai 150', [
    (100, 'Food'),
    (150, 'Food'),
  ]);
  check('Rs prefix', 'Rs. 300 petrol, Rs 200 chai', [
    (300, 'Transport'),
    (200, 'Food'),
  ]);
  check('item-first no commas', 'petrol 300 chai 200 grocery 500', [
    (300, 'Transport'),
    (200, 'Food'),
    (500, 'Groceries'),
  ]);
  check('sadhe teen sau', 'sadhe teen sau ki chai', [(350, 'Food')]);
  check('dhai hazar', 'dhai hazar ka doodh', [(2500, 'Groceries')]);
  check('sawa sau', 'sawa sau rupay rickshaw', [(125, 'Transport')]);
  check('rent not transport', 'makaan ka kiraya 15000', [(15000, 'Bills')]);
  check('thousands comma', '1,500 rupay ka doodh', [(1500, 'Groceries')]);
  check('english words', 'two thousand five hundred electricity bill', [
    (2500, 'Bills'),
  ]);
  check('twenty five', 'twenty five rupees tea', [(25, 'Food')]);
  check('weight is not amount', '10 kilo aata 1500', [(1500, 'Groceries')]);
  check('chatter ignored', 'aj ka din acha tha', [], ignored: ['din acha']);
  check('empty', '', []);
  check('amount only', '250', [(250, 'Other')]);
  check('bare so is not a number', 'so I bought chai for 50 rupees', [
    (50, 'Food'),
  ]);

  stdout.writeln(failures == 0 ? '\nALL PASSED' : '\n$failures FAILED');
  exit(failures == 0 ? 0 : 1);
}
