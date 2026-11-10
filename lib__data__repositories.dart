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

/// A title the user has typed several times, with the category it was last filed under.
class TitleSuggestion {
  final String title;
  final int categoryId;
  final int count;
  const TitleSuggestion(this.title, this.categoryId, this.count);
}

class ExpenseRepository {
  /// Titles used at least [minCount] times, most used first. Titles that are
  /// just a category name (filled in when no title was typed) are left out.
  Future<List<TitleSuggestion>> frequentTitles({
    int minCount = 2,
    int limit = 40,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
      'SELECT e.description AS title, e.category_id AS cat, '
      'COUNT(*) AS cnt, MAX(e.date) AS last '
      'FROM expenses e JOIN categories c ON c.id = e.category_id '
      "WHERE TRIM(e.description) != '' "
      'AND LOWER(TRIM(e.description)) != LOWER(c.name) '
      'GROUP BY LOWER(TRIM(e.description)) '
      'HAVING COUNT(*) >= ? '
      'ORDER BY cnt DESC, last DESC LIMIT ?',
      [minCount, limit],
    );
    return [
      for (final r in rows)
        TitleSuggestion(
          (r['title'] as String).trim(),
          r['cat'] as int,
          (r['cnt'] as num).toInt(),
        ),
    ];
  }

  /// Adds one expense and returns its id (so it can be undone).
  Future<int> insert(Expense e) async {
    final db = await DatabaseHelper.instance.database;
    return db.insert('expenses', e.toMap());
  }

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
      'SELECT e.*, c.name AS category_name, a.name AS account_name FROM expenses e '
      'JOIN categories c ON c.id = e.category_id '
      'LEFT JOIN accounts a ON a.id = e.account_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY e.date DESC, e.id DESC ${limit != null ? 'LIMIT $limit' : ''}',
      args,
    );
    return rows.map(Expense.fromMap).toList();
  }

  /// Date of the oldest expense, or null when there are none.
  Future<DateTime?> firstDate() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('SELECT MIN(date) AS d FROM expenses');
    final v = rows.first['d'];
    return v == null ? null : Fmt.parseKey(v as String);
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

  Future<void> addExtra(
    double amount,
    String source,
    DateTime date, {
    int? accountId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('incomes', {
      'account_id': accountId,
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

class AccountRepository {
  Future<List<Account>> all() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('accounts', orderBy: 'sort, id');
    return rows.map(Account.fromMap).toList();
  }

  /// opening balance + deposits + transfers in - transfers out (incl. fee) - expenses
  Future<List<AccountBalance>> balances() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT a.*,
        a.opening_balance
        + COALESCE((SELECT SUM(i.amount) FROM incomes i WHERE i.account_id = a.id), 0)
        + COALESCE((SELECT SUM(t.amount) FROM transfers t WHERE t.to_id = a.id), 0)
        - COALESCE((SELECT SUM(t.amount + t.fee) FROM transfers t WHERE t.from_id = a.id), 0)
        - COALESCE((SELECT SUM(e.amount) FROM expenses e WHERE e.account_id = a.id), 0)
        AS balance
      FROM accounts a ORDER BY a.sort, a.id''');
    return rows
        .map(
          (r) => AccountBalance(
            Account.fromMap(r),
            (r['balance'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<double> balanceOf(int id) async {
    final all = await balances();
    for (final b in all) {
      if (b.account.id == id) return b.balance;
    }
    return 0;
  }

  /// [currentBalance] becomes the opening balance (no history yet).
  Future<void> insert(String name, String type, double currentBalance) async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.rawQuery(
      'SELECT COALESCE(MAX(sort), 0) + 1 AS n FROM accounts',
    );
    await db.insert('accounts', {
      'name': name,
      'type': type,
      'opening_balance': currentBalance,
      'sort': (r.first['n'] as num).toInt(),
    });
  }

  Future<void> update(int id, String name, String type) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'accounts',
      {'name': name, 'type': type},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Makes the computed balance equal [actual] by moving the opening balance.
  Future<void> correctBalance(int id, double actual) async {
    final db = await DatabaseHelper.instance.database;
    final current = await balanceOf(id);
    final rows = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final opening = (rows.first['opening_balance'] as num).toDouble();
    await db.update(
      'accounts',
      {'opening_balance': opening + (actual - current)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> hasActivity(int id) async {
    final db = await DatabaseHelper.instance.database;
    final r = await db.rawQuery(
      'SELECT (SELECT COUNT(*) FROM expenses WHERE account_id = ?) '
      '+ (SELECT COUNT(*) FROM incomes WHERE account_id = ?) '
      '+ (SELECT COUNT(*) FROM transfers WHERE from_id = ? OR to_id = ?) AS n',
      [id, id, id, id],
    );
    return (r.first['n'] as num).toInt() > 0;
  }

  Future<void> delete(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addTransfer({
    required int fromId,
    required int toId,
    required double amount,
    required double fee,
    required DateTime date,
    required String note,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('transfers', {
      'from_id': fromId,
      'to_id': toId,
      'amount': amount,
      'fee': fee,
      'date': Fmt.key(date),
      'note': note,
    });
  }

  Future<void> deleteTransfer(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('transfers', where: 'id = ?', whereArgs: [id]);
  }

  /// Latest entries of ALL accounts together, newest first. A transfer is
  /// listed once (as "From → To"), its [ActivityItem.delta] is the plain amount.
  Future<List<ActivityItem>> allActivity({int limit = 30}) async {
    final db = await DatabaseHelper.instance.database;
    final items = <ActivityItem>[];

    final ex = await db.rawQuery(
      'SELECT e.id, e.amount, e.description, e.date, e.account_id, '
      'c.name AS cat, a.name AS acc FROM expenses e '
      'JOIN categories c ON c.id = e.category_id '
      'JOIN accounts a ON a.id = e.account_id '
      'ORDER BY e.date DESC, e.id DESC LIMIT $limit',
    );
    for (final r in ex) {
      final desc = (r['description'] as String?) ?? '';
      items.add(
        ActivityItem(
          'expense',
          r['id'] as int,
          desc.isEmpty ? r['cat'] as String : desc,
          r['cat'] as String,
          -(r['amount'] as num).toDouble(),
          Fmt.parseKey(r['date'] as String),
          account: r['acc'] as String,
          accountId: r['account_id'] as int,
        ),
      );
    }

    final inc = await db.rawQuery(
      'SELECT i.id, i.amount, i.source, i.date, i.account_id, a.name AS acc '
      'FROM incomes i JOIN accounts a ON a.id = i.account_id '
      'ORDER BY i.date DESC, i.id DESC LIMIT $limit',
    );
    for (final r in inc) {
      final src = (r['source'] as String?) ?? '';
      items.add(
        ActivityItem(
          'deposit',
          r['id'] as int,
          src.isEmpty ? 'Money added' : src,
          'Money added',
          (r['amount'] as num).toDouble(),
          Fmt.parseKey(r['date'] as String),
          account: r['acc'] as String,
          accountId: r['account_id'] as int,
        ),
      );
    }

    final tr = await db.rawQuery(
      'SELECT t.*, f.name AS from_name, o.name AS to_name FROM transfers t '
      'JOIN accounts f ON f.id = t.from_id JOIN accounts o ON o.id = t.to_id '
      'ORDER BY t.date DESC, t.id DESC LIMIT $limit',
    );
    for (final r in tr) {
      final fee = (r['fee'] as num).toDouble();
      final note = (r['note'] as String?) ?? '';
      items.add(
        ActivityItem(
          'transfer',
          r['id'] as int,
          '${r['from_name']} → ${r['to_name']}',
          [
            if (fee > 0) 'fee ${Fmt.money(fee)}',
            if (note.isNotEmpty) note,
          ].join(' • '),
          (r['amount'] as num).toDouble(),
          Fmt.parseKey(r['date'] as String),
          account: 'Transfer',
          accountId: r['from_id'] as int,
        ),
      );
    }

    items.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
    return items.take(limit).toList();
  }

  /// Everything that touched this account, newest first.
  Future<List<ActivityItem>> activity(int accountId, {int limit = 80}) async {
    final db = await DatabaseHelper.instance.database;
    final items = <ActivityItem>[];

    final ex = await db.rawQuery(
      'SELECT e.id, e.amount, e.description, e.date, c.name AS cat FROM expenses e '
      'JOIN categories c ON c.id = e.category_id WHERE e.account_id = ? '
      'ORDER BY e.date DESC, e.id DESC LIMIT $limit',
      [accountId],
    );
    for (final r in ex) {
      final desc = (r['description'] as String?) ?? '';
      items.add(
        ActivityItem(
          'expense',
          r['id'] as int,
          desc.isEmpty ? r['cat'] as String : desc,
          r['cat'] as String,
          -(r['amount'] as num).toDouble(),
          Fmt.parseKey(r['date'] as String),
        ),
      );
    }

    final inc = await db.rawQuery(
      'SELECT id, amount, source, date FROM incomes WHERE account_id = ? '
      'ORDER BY date DESC, id DESC LIMIT $limit',
      [accountId],
    );
    for (final r in inc) {
      final src = (r['source'] as String?) ?? '';
      items.add(
        ActivityItem(
          'deposit',
          r['id'] as int,
          src.isEmpty ? 'Money added' : src,
          'Money added',
          (r['amount'] as num).toDouble(),
          Fmt.parseKey(r['date'] as String),
        ),
      );
    }

    final tr = await db.rawQuery(
      'SELECT t.*, f.name AS from_name, o.name AS to_name FROM transfers t '
      'JOIN accounts f ON f.id = t.from_id JOIN accounts o ON o.id = t.to_id '
      'WHERE t.from_id = ? OR t.to_id = ? ORDER BY t.date DESC, t.id DESC LIMIT $limit',
      [accountId, accountId],
    );
    for (final r in tr) {
      final out = r['from_id'] == accountId;
      final amount = (r['amount'] as num).toDouble();
      final fee = (r['fee'] as num).toDouble();
      final other = out ? r['to_name'] as String : r['from_name'] as String;
      final note = (r['note'] as String?) ?? '';
      final kindLabel = out && (r['to_name'] as String) == 'Cash'
          ? 'Withdrawal'
          : 'Transfer';
      items.add(
        ActivityItem(
          'transfer',
          r['id'] as int,
          out ? '$kindLabel to $other' : 'Received from $other',
          [
            if (fee > 0 && out) 'fee ${Fmt.money(fee)}',
            if (note.isNotEmpty) note,
          ].join(' • '),
          out ? -(amount + fee) : amount,
          Fmt.parseKey(r['date'] as String),
        ),
      );
    }

    items.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
    return items.take(limit).toList();
  }
}
