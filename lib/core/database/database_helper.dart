import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;
  static const _uuid = Uuid();

  static const _dbName = 'tally.db';
  static const _dbVersion = 2;

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
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // Bersihkan transaksi orphan dari wallet yang sudah tidak ada
        await db.execute('''
          DELETE FROM transactions 
          WHERE wallet_id IS NOT NULL 
            AND wallet_id NOT IN (SELECT id FROM wallets)
            AND source_wallet_id IS NULL
        ''');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Wallets table (PRD Bab 8)
    await db.execute('''
      CREATE TABLE wallets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'cash',
        opening_balance INTEGER NOT NULL DEFAULT 0,
        color TEXT,
        icon TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 2. Categories table (PRD Bab 8)
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        icon TEXT,
        color TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 3. Daily Budgets / Kuota Harian (PRD Bab 8)
    await db.execute('''
      CREATE TABLE daily_budgets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        daily_limit INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 4. Transactions table (PRD Bab 8)
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense', 'transfer')),
        amount INTEGER NOT NULL,
        category_id TEXT,
        wallet_id TEXT,
        source_wallet_id TEXT,
        destination_wallet_id TEXT,
        budget_id TEXT,
        occurred_at TEXT NOT NULL,
        local_date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
        FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE SET NULL,
        FOREIGN KEY (source_wallet_id) REFERENCES wallets(id) ON DELETE SET NULL,
        FOREIGN KEY (destination_wallet_id) REFERENCES wallets(id) ON DELETE SET NULL,
        FOREIGN KEY (budget_id) REFERENCES daily_budgets(id) ON DELETE SET NULL
      )
    ''');

    // Indexing for rapid queries
    await db.execute('CREATE INDEX idx_tx_local_date ON transactions(local_date)');
    await db.execute('CREATE INDEX idx_tx_wallet_id ON transactions(wallet_id)');
    await db.execute('CREATE INDEX idx_tx_budget_id ON transactions(budget_id)');

    // Seed default categories and default wallet
    await _seedDefaultData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Hapus tabel lama dari versi uji coba awal untuk migrasi ke skema PRD
      await db.execute('DROP TABLE IF EXISTS transactions');
      await db.execute('DROP TABLE IF EXISTS budgets');
      await db.execute('DROP TABLE IF EXISTS daily_budgets');
      await db.execute('DROP TABLE IF EXISTS categories');
      await db.execute('DROP TABLE IF EXISTS wallets');

      // Buat ulang tabel dengan skema baru dan seed data
      await _onCreate(db, newVersion);
    }
  }

  Future<void> _seedDefaultData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Default Wallet: Tunai
    await db.insert('wallets', {
      'id': _uuid.v4(),
      'name': 'Tunai',
      'type': 'cash',
      'opening_balance': 0,
      'color': '#0A0A0A',
      'icon': 'wallet',
      'is_archived': 0,
      'created_at': now,
      'updated_at': now,
    });

    // Default Categories (Monokrom / Netral)
    final categories = [
      // Expense categories
      {'name': 'Makanan & Minuman', 'icon': 'food', 'type': 'expense'},
      {'name': 'Transportasi', 'icon': 'transport', 'type': 'expense'},
      {'name': 'Belanja', 'icon': 'shopping', 'type': 'expense'},
      {'name': 'Tagihan & Utilitas', 'icon': 'bill', 'type': 'expense'},
      {'name': 'Hiburan', 'icon': 'entertainment', 'type': 'expense'},
      {'name': 'Kesehatan', 'icon': 'health', 'type': 'expense'},
      {'name': 'Pendidikan', 'icon': 'education', 'type': 'expense'},
      {'name': 'Lainnya', 'icon': 'other', 'type': 'expense'},
      // Income categories
      {'name': 'Gaji', 'icon': 'salary', 'type': 'income'},
      {'name': 'Freelance', 'icon': 'freelance', 'type': 'income'},
      {'name': 'Investasi', 'icon': 'investment', 'type': 'income'},
      {'name': 'Bonus / Hadiah', 'icon': 'gift', 'type': 'income'},
      {'name': 'Lainnya', 'icon': 'other', 'type': 'income'},
    ];

    for (final cat in categories) {
      await db.insert('categories', {
        'id': _uuid.v4(),
        'name': cat['name']!,
        'type': cat['type']!,
        'icon': cat['icon']!,
        'color': '#0A0A0A',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
  }
}
