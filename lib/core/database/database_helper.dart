import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  static const _dbName = 'tally.db';
  static const _dbVersion = 1;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE wallets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'IDR',
        icon TEXT,
        color INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT,
        color INTEGER,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wallet_id INTEGER NOT NULL,
        category_id INTEGER,
        amount REAL NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense', 'transfer')),
        note TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        amount REAL NOT NULL,
        spent REAL NOT NULL DEFAULT 0,
        period TEXT NOT NULL CHECK(period IN ('daily', 'weekly', 'monthly', 'yearly')),
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');

    // Seed default categories
    await _seedDefaultCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
  }

  Future<void> _seedDefaultCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    final categories = [
      // Expense categories
      {'name': 'Makanan & Minuman', 'icon': '🍔', 'color': 0xFFFF6B6B, 'type': 'expense', 'created_at': now},
      {'name': 'Transportasi', 'icon': '🚗', 'color': 0xFF4ECDC4, 'type': 'expense', 'created_at': now},
      {'name': 'Belanja', 'icon': '🛒', 'color': 0xFF45B7D1, 'type': 'expense', 'created_at': now},
      {'name': 'Hiburan', 'icon': '🎮', 'color': 0xFF96CEB4, 'type': 'expense', 'created_at': now},
      {'name': 'Kesehatan', 'icon': '💊', 'color': 0xFFFF9FF3, 'type': 'expense', 'created_at': now},
      {'name': 'Pendidikan', 'icon': '📚', 'color': 0xFFFECA57, 'type': 'expense', 'created_at': now},
      {'name': 'Tagihan', 'icon': '💡', 'color': 0xFFFF6348, 'type': 'expense', 'created_at': now},
      {'name': 'Lainnya', 'icon': '📦', 'color': 0xFF747D8C, 'type': 'expense', 'created_at': now},
      // Income categories
      {'name': 'Gaji', 'icon': '💼', 'color': 0xFF2ED573, 'type': 'income', 'created_at': now},
      {'name': 'Freelance', 'icon': '💻', 'color': 0xFF1E90FF, 'type': 'income', 'created_at': now},
      {'name': 'Investasi', 'icon': '📈', 'color': 0xFFFFA502, 'type': 'income', 'created_at': now},
      {'name': 'Hadiah', 'icon': '🎁', 'color': 0xFFECCC68, 'type': 'income', 'created_at': now},
    ];

    for (final cat in categories) {
      await db.insert('categories', cat);
    }
  }
}
