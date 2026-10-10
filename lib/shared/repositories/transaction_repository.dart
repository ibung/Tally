import 'package:tally/core/database/database_helper.dart';
import 'package:tally/shared/models/transaction_model.dart';

class TransactionRepository {
  final DatabaseHelper _db;

  TransactionRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  static const String _joinedQuery = '''
    SELECT 
      t.*,
      c.name as category_name,
      c.icon as category_icon,
      w.name as wallet_name,
      sw.name as source_wallet_name,
      dw.name as destination_wallet_name,
      b.name as budget_name
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    LEFT JOIN wallets w ON t.wallet_id = w.id
    LEFT JOIN wallets sw ON t.source_wallet_id = sw.id
    LEFT JOIN wallets dw ON t.destination_wallet_id = dw.id
    LEFT JOIN daily_budgets b ON t.budget_id = b.id
  ''';

  Future<List<TransactionModel>> getAll({
    String? walletId,
    String? type,
    String? localDate, // YYYY-MM-DD
    String? startDate, // YYYY-MM-DD
    String? endDate, // YYYY-MM-DD
    String? searchQuery,
    int limit = 100,
    int offset = 0,
  }) async {
    final database = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (walletId != null) {
      conditions.add('(t.wallet_id = ? OR t.source_wallet_id = ? OR t.destination_wallet_id = ?)');
      args.addAll([walletId, walletId, walletId]);
    }
    if (type != null) {
      conditions.add('t.type = ?');
      args.add(type);
    }
    if (localDate != null) {
      conditions.add('t.local_date = ?');
      args.add(localDate);
    }
    if (startDate != null) {
      conditions.add('t.local_date >= ?');
      args.add(startDate);
    }
    if (endDate != null) {
      conditions.add('t.local_date <= ?');
      args.add(endDate);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('(t.note LIKE ? OR c.name LIKE ? OR w.name LIKE ?)');
      final pattern = '%${searchQuery.trim()}%';
      args.addAll([pattern, pattern, pattern]);
    }

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final maps = await database.rawQuery(
      '$_joinedQuery $where ORDER BY t.occurred_at DESC LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );

    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<TransactionModel?> getById(String id) async {
    final database = await _db.database;
    final maps = await database.rawQuery(
      '$_joinedQuery WHERE t.id = ?',
      [id],
    );
    if (maps.isEmpty) return null;
    return TransactionModel.fromMap(maps.first);
  }

  Future<int> insert(TransactionModel transaction) async {
    final database = await _db.database;
    return database.insert('transactions', transaction.toMap());
  }

  Future<int> update(TransactionModel transaction) async {
    final database = await _db.database;
    return database.update(
      'transactions',
      transaction.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> delete(String id) async {
    final database = await _db.database;
    return database.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Ringkasan pemasukan dan pengeluaran pada tanggal tertentu (localDate: YYYY-MM-DD)
  Future<({int income, int expense})> getDailySummary(String localDate) async {
    final database = await _db.database;
    final result = await database.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as total_income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as total_expense
      FROM transactions
      WHERE local_date = ?
    ''', [localDate]);

    return (
      income: (result.first['total_income'] as num?)?.toInt() ?? 0,
      expense: (result.first['total_expense'] as num?)?.toInt() ?? 0,
    );
  }

  /// Menghitung total pengeluaran untuk suatu kuota pada tanggal tertentu (PRD Bab 7)
  Future<int> getBudgetSpentForDate(String budgetId, String localDate) async {
    final database = await _db.database;
    final result = await database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE budget_id = ? AND local_date = ? AND type = 'expense'
    ''', [budgetId, localDate]);

    return (result.first['total'] as num?)?.toInt() ?? 0;
  }

  /// Menghitung saldo akhir historis hingga akhir tanggal terpilih (PRD Bab 7)
  Future<int> getHistoricalEndBalance(String localDate) async {
    final database = await _db.database;

    // Total saldo awal semua wallet
    final walletRes = await database.rawQuery(
      'SELECT COALESCE(SUM(opening_balance), 0) as total_opening FROM wallets WHERE is_archived = 0',
    );
    final totalOpening = (walletRes.first['total_opening'] as num?)?.toInt() ?? 0;

    // Pemasukan sampai tanggal tersebut
    final incomeRes = await database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM transactions
      WHERE type = 'income' AND local_date <= ?
    ''', [localDate]);
    final totalIncome = (incomeRes.first['total'] as num?)?.toInt() ?? 0;

    // Pengeluaran sampai tanggal tersebut
    final expenseRes = await database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM transactions
      WHERE type = 'expense' AND local_date <= ?
    ''', [localDate]);
    final totalExpense = (expenseRes.first['total'] as num?)?.toInt() ?? 0;

    // Catatan: Transfer tidak mengubah total saldo seluruh wallet (PRD Bab 7)
    return totalOpening + totalIncome - totalExpense;
  }
}
