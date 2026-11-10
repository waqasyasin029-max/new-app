import '../core/format.dart';

class Category {
  final int id;
  final String name;
  const Category(this.id, this.name);
  factory Category.fromMap(Map<String, Object?> m) =>
      Category(m['id'] as int, m['name'] as String);
}

class Expense {
  final int? id;
  final double amount;
  final int categoryId;
  final String? categoryName;
  final int? accountId;
  final String? accountName;
  final String description;
  final DateTime date;
  final String source; // 'voice' | 'manual'
  final String? rawText;

  const Expense({
    this.id,
    required this.amount,
    required this.categoryId,
    this.categoryName,
    this.accountId,
    this.accountName,
    required this.description,
    required this.date,
    this.source = 'manual',
    this.rawText,
  });

  Map<String, Object?> toMap() => {
    'amount': amount,
    'category_id': categoryId,
    'account_id': accountId,
    'description': description,
    'date': Fmt.key(date),
    'source': source,
    'raw_text': rawText,
  };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
    id: m['id'] as int,
    amount: (m['amount'] as num).toDouble(),
    categoryId: m['category_id'] as int,
    categoryName: m['category_name'] as String?,
    accountId: m['account_id'] as int?,
    accountName: m['account_name'] as String?,
    description: (m['description'] as String?) ?? '',
    date: Fmt.parseKey(m['date'] as String),
    source: (m['source'] as String?) ?? 'manual',
    rawText: m['raw_text'] as String?,
  );
}

class Income {
  final int id;
  final double amount;
  final String source;
  final DateTime date;
  const Income(this.id, this.amount, this.source, this.date);
  factory Income.fromMap(Map<String, Object?> m) => Income(
    m['id'] as int,
    (m['amount'] as num).toDouble(),
    (m['source'] as String?) ?? '',
    Fmt.parseKey(m['date'] as String),
  );
}

class SalaryInfo {
  final double amount;
  final String?
  carriedFromMonth; // yyyy-MM when the month has no salary of its own
  const SalaryInfo(this.amount, [this.carriedFromMonth]);
}

class CategoryTotal {
  final int id;
  final String name;
  final double total;
  final int count;
  const CategoryTotal(this.id, this.name, this.total, this.count);
}

class Account {
  final int id;
  final String name;
  final String type; // cash | wallet | bank
  final double openingBalance;
  const Account(this.id, this.name, this.type, this.openingBalance);
  factory Account.fromMap(Map<String, Object?> m) => Account(
    m['id'] as int,
    m['name'] as String,
    m['type'] as String,
    (m['opening_balance'] as num).toDouble(),
  );
  bool get isCash => type == 'cash';
}

class AccountBalance {
  final Account account;
  final double balance;
  const AccountBalance(this.account, this.balance);
}

/// One line in an account's activity list. [delta] is signed (+ in, - out).
class ActivityItem {
  final String kind; // expense | transfer | deposit
  final int id;
  final String title;
  final String subtitle;
  final double delta;
  final DateTime date;

  /// Only filled for the all-accounts list: which account this belongs to.
  final String account;
  final int accountId;
  const ActivityItem(
    this.kind,
    this.id,
    this.title,
    this.subtitle,
    this.delta,
    this.date, {
    this.account = '',
    this.accountId = 0,
  });
}
