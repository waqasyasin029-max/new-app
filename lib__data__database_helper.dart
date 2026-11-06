import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const defaultCategories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Groceries',
    'Health',
    'Entertainment',
    'Other',
  ];

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'kharcha.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            is_default INTEGER NOT NULL DEFAULT 1)''');
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            category_id INTEGER NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            date TEXT NOT NULL,
            source TEXT NOT NULL DEFAULT 'manual',
            raw_text TEXT,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY(category_id) REFERENCES categories(id))''');
        await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
        await db.execute('''
          CREATE TABLE incomes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            source TEXT NOT NULL DEFAULT '',
            date TEXT NOT NULL,
            month TEXT NOT NULL,
            is_salary INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''');
        await db.execute('CREATE INDEX idx_incomes_month ON incomes(month)');
        final batch = db.batch();
        for (final name in defaultCategories) {
          batch.insert('categories', {'name': name, 'is_default': 1});
        }
        await batch.commit(noResult: true);
      },
    );
  }
}
