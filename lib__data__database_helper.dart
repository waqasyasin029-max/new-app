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
      version: 2,
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
            account_id INTEGER,
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
            account_id INTEGER,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''');
        await db.execute('CREATE INDEX idx_incomes_month ON incomes(month)');
        final batch = db.batch();
        for (final name in defaultCategories) {
          batch.insert('categories', {'name': name, 'is_default': 1});
        }
        await batch.commit(noResult: true);
        await _createAccountTables(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await db.execute(
            'ALTER TABLE expenses ADD COLUMN account_id INTEGER',
          );
          await db.execute('ALTER TABLE incomes ADD COLUMN account_id INTEGER');
          await _createAccountTables(db);
        }
      },
    );
  }

  Future<void> _createAccountTables(Database db) async {
    await db.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL,
        opening_balance REAL NOT NULL DEFAULT 0,
        sort INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''
      CREATE TABLE transfers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_id INTEGER NOT NULL,
        to_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        fee REAL NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''');
    // No accounts are created here: the first-time setup asks which ones the
    // person really has.
  }
}
