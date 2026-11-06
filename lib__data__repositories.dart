import '../core/format.dart';
import 'database_helper.dart';
import 'models.dart';

class CategoryRepository {
  Future<List<Category>> all() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('categories', orderBy: 'id');
    return rows.map(Category.fromMap).toList();
  }
}

class ExpenseRepository {
  Future<void> insertMany(List<Expense> list) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (final e in list) {
      batch.insert('expenses', e.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> update(Expense e) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('expenses', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Expense>> list({
    DateTime? from,
    DateTime? to,
    int? categoryId,
    String? search,
    int? limit,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('e.date >= ?');
      args.add(Fmt.key(from));
    }
    if (to != null) {
      where.add('e.date <= ?');
      args.add(Fmt.key(to));
    }
    if (categoryId != null) {
      where.add('e.category_id = ?');
      args.add(categoryId);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('e.description LIKE ?');
      args.add('%${search.trim()}%');
    }
    final rows = await db.rawQuery(
      'SELECT e.*, c.name AS category_name FROM expenses e '
      'JOIN categories c ON c.id = e.category_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY e.date DESC, e.id DESC ${limit != null ? 'LIMIT $limit' : ''}',
      args,
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<double> total(DateTime from, DateTime to) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS t FROM expenses WHERE date >= ? AND date <= ?',
      [Fmt.key(from), Fmt.key(to)],
    );
    return (rows.first['t'] as num).toDouble();
  }

  Future<List<CategoryTotal>> categoryTotals(DateTime from, DateTime to) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT c.id AS id, c.name AS name, SUM(e.amount) AS total, COUNT(*) AS cnt '
      'FROM expenses e JOIN categories c ON c.id = e.category_id '
      'WHERE e.date >= ? AND e.date <= ? GROUP BY c.id ORDER BY total DESC',
      [Fmt.key(from), Fmt.key(to)],
    );
    return rows
        .map(
          (r) => CategoryTotal(
            r['id'] as int,
            r['name'] as String,
            (r['total'] as num).toDouble(),
            r['cnt'] as int,
          ),
        )
        .toList();
  }

  /// Map of 'yyyy-MM-dd' -> total for that day (only days that have expenses).
  Future<Map<String, double>> dailyTotals(DateTime from, DateTime to) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT date, SUM(amount) AS total FROM expenses '
      'WHERE date >= ? AND date <= ? GROUP BY date ORDER BY date',
      [Fmt.key(from), Fmt.key(to)],
    );
    return {
      for (final r in rows) r['date'] as String: (r['total'] as num).toDouble(),
    };
  }
}

class IncomeRepository {
  /// Salary for [month]. If that month has none, the latest earlier salary is carried forward.
  Future<SalaryInfo> salaryFor(DateTime month) async {
    final db = await DatabaseHelper.instance.database;
    final ym = Fmt.monthKey(month);
    final rows = await db.query(
      'incomes',
      where: 'is_salary = 1 AND month <= ?',
      whereArgs: [ym],
      orderBy: 'month DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return const SalaryInfo(0);
    final m = rows.first['month'] as String;
    return SalaryInfo(
      (rows.first['amount'] as num).toDouble(),
      m == ym ? null : m,
    );
  }

  Future<void> setSalary(DateTime month, double amount) async {
    final db = await DatabaseHelper.instance.database;
    final ym = Fmt.monthKey(month);
    await db.transaction((txn) async {
      await txn.delete(
        'incomes',
        where: 'is_salary = 1 AND month = ?',
        whereArgs: [ym],
      );
      await txn.insert('incomes', {
        'amount': amount,
        'source': 'Salary',
        'date': Fmt.key(Fmt.firstOfMonth(month)),
        'month': ym,
        'is_salary': 1,
      });
    });
  }

  Future<List<Income>> extras(DateTime month) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'incomes',
      where: 'is_salary = 0 AND month = ?',
      whereArgs: [Fmt.monthKey(month)],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map(Income.fromMap).toList();
  }

  Future<void> addExtra(double amount, String source, DateTime date) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('incomes', {
      'amount': amount,
      'source': source,
      'date': Fmt.key(date),
      'month': Fmt.monthKey(date),
      'is_salary': 0,
    });
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('incomes', where: 'id = ?', whereArgs: [id]);
  }

  /// Salary + other income for the month.
  Future<double> totalIncome(DateTime month) async {
    final s = await salaryFor(month);
    final e = await extras(month);
    return s.amount + e.fold<double>(0, (a, i) => a + i.amount);
  }
}
