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
  final String description;
  final DateTime date;
  final String source; // 'voice' | 'manual'
  final String? rawText;

  const Expense({
    this.id,
    required this.amount,
    required this.categoryId,
    this.categoryName,
    required this.description,
    required this.date,
    this.source = 'manual',
    this.rawText,
  });

  Map<String, Object?> toMap() => {
    'amount': amount,
    'category_id': categoryId,
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
