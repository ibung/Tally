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

  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> reopenDatabase() async {
    await closeDatabase();
    _database = await _initDatabase();
    return _database!;
  }

  Future<int> getTransactionCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM transactions');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> isDatabaseEmpty() async {
    final db = await database;
    final txCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as cnt FROM transactions'),
    ) ?? 0;
    final budgetCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as cnt FROM daily_budgets'),
    ) ?? 0;
    final walletCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) as cnt FROM wallets'),
    ) ?? 0;

    // Database dianggap kosong jika belum ada transaksi, belum ada kuota, dan wallet <= 1 (default)
    return txCount == 0 && budgetCount == 0 && walletCount <= 1;
  }

  /// Menggabungkan database eksternal (hasil unduh dari cloud) ke dalam database lokal.
  /// Mencegah hilangnya data transaksi saat kedua HP memiliki perubahan bersamaan (smart merge).
  Future<void> mergeExternalDatabase(String externalDbPath) async {
    final externalDb = await openReadOnlyDatabase(externalDbPath);
    try {
      final localDb = await database;

      await localDb.transaction((txn) async {
        // 1. Wallets
        final remoteWallets = await externalDb.query('wallets');
        for (final row in remoteWallets) {
          final id = row['id'];
          if (id == null) continue;
          final existing = await txn.query('wallets', where: 'id = ?', whereArgs: [id], limit: 1);
          if (existing.isEmpty) {
            await txn.insert('wallets', row);
          } else {
            final localUpdated = DateTime.tryParse(existing.first['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final remoteUpdated = DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            if (remoteUpdated.isAfter(localUpdated)) {
              await txn.update('wallets', row, where: 'id = ?', whereArgs: [id]);
            }
          }
        }

        // 2. Categories
        final remoteCategories = await externalDb.query('categories');
        for (final row in remoteCategories) {
          final id = row['id'];
          if (id == null) continue;
          final existing = await txn.query('categories', where: 'id = ?', whereArgs: [id], limit: 1);
          if (existing.isEmpty) {
            await txn.insert('categories', row);
          } else {
            final localUpdated = DateTime.tryParse(existing.first['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final remoteUpdated = DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            if (remoteUpdated.isAfter(localUpdated)) {
              await txn.update('categories', row, where: 'id = ?', whereArgs: [id]);
            }
          }
        }

        // 3. Daily Budgets
        final remoteBudgets = await externalDb.query('daily_budgets');
        for (final row in remoteBudgets) {
          final id = row['id'];
          if (id == null) continue;
          final existing = await txn.query('daily_budgets', where: 'id = ?', whereArgs: [id], limit: 1);
          if (existing.isEmpty) {
            await txn.insert('daily_budgets', row);
          } else {
            final localUpdated = DateTime.tryParse(existing.first['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final remoteUpdated = DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            if (remoteUpdated.isAfter(localUpdated)) {
              await txn.update('daily_budgets', row, where: 'id = ?', whereArgs: [id]);
            }
          }
        }

        // 4. Transactions
        final remoteTransactions = await externalDb.query('transactions');
        for (final row in remoteTransactions) {
          final id = row['id'];
          if (id == null) continue;
          final existing = await txn.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
          if (existing.isEmpty) {
            await txn.insert('transactions', row);
          } else {
            final localUpdated = DateTime.tryParse(existing.first['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final remoteUpdated = DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            if (remoteUpdated.isAfter(localUpdated)) {
              await txn.update('transactions', row, where: 'id = ?', whereArgs: [id]);
            }
          }
        }
      });
    } finally {
      await externalDb.close();
    }
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

        // Pastikan kolom period ada di tabel daily_budgets
        final columns = await db.rawQuery('PRAGMA table_info(daily_budgets)');
        final hasPeriod = columns.any((c) => c['name'] == 'period');
        if (!hasPeriod) {
          await db.execute("ALTER TABLE daily_budgets ADD COLUMN period TEXT NOT NULL DEFAULT 'daily'");
        }
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

    // 3. Daily Budgets / Kuota (Harian, Mingguan, Bulanan)
    await db.execute('''
      CREATE TABLE daily_budgets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        daily_limit INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        period TEXT NOT NULL DEFAULT 'daily',
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
