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
      c.color as category_color,
      w.name as wallet_name
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    LEFT JOIN wallets w ON t.wallet_id = w.id
  ''';

  Future<List<TransactionModel>> getAll({
    int? walletId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    final database = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (walletId != null) {
      conditions.add('t.wallet_id = ?');
      args.add(walletId);
    }
    if (type != null) {
      conditions.add('t.type = ?');
      args.add(type);
    }
    if (startDate != null) {
      conditions.add('t.date >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      conditions.add('t.date <= ?');
      args.add(endDate.toIso8601String());
    }

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final maps = await database.rawQuery(
      '$_joinedQuery $where ORDER BY t.date DESC LIMIT ? OFFSET ?',
      [...args, limit, offset],
    );

    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<TransactionModel?> getById(int id) async {
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
    return database.transaction((txn) async {
      final id = await txn.insert('transactions', transaction.toMap());
      // Update wallet balance
      final delta = transaction.type == TransactionType.income
          ? transaction.amount
          : -transaction.amount;
      await txn.rawUpdate(
        'UPDATE wallets SET balance = balance + ?, updated_at = ? WHERE id = ?',
        [delta, DateTime.now().toIso8601String(), transaction.walletId],
      );
      return id;
    });
  }

  Future<void> update(TransactionModel oldTx, TransactionModel newTx) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      // Revert old transaction effect
      final oldDelta = oldTx.type == TransactionType.income
          ? -oldTx.amount
          : oldTx.amount;
      await txn.rawUpdate(
        'UPDATE wallets SET balance = balance + ?, updated_at = ? WHERE id = ?',
        [oldDelta, DateTime.now().toIso8601String(), oldTx.walletId],
      );
      // Apply new transaction effect
      final newDelta = newTx.type == TransactionType.income
          ? newTx.amount
          : -newTx.amount;
      await txn.rawUpdate(
        'UPDATE wallets SET balance = balance + ?, updated_at = ? WHERE id = ?',
        [newDelta, DateTime.now().toIso8601String(), newTx.walletId],
      );
      await txn.update(
        'transactions',
        newTx.copyWith(updatedAt: DateTime.now()).toMap(),
        where: 'id = ?',
        whereArgs: [newTx.id],
      );
    });
  }

  Future<void> delete(TransactionModel transaction) async {
    final database = await _db.database;
    await database.transaction((txn) async {
      await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
      // Revert wallet balance
      final delta = transaction.type == TransactionType.income
          ? -transaction.amount
          : transaction.amount;
      await txn.rawUpdate(
        'UPDATE wallets SET balance = balance + ?, updated_at = ? WHERE id = ?',
        [delta, DateTime.now().toIso8601String(), transaction.walletId],
      );
    });
  }

  Future<Map<String, double>> getSummary({
    required DateTime startDate,
    required DateTime endDate,
    int? walletId,
  }) async {
    final database = await _db.database;
    final args = <dynamic>[
      startDate.toIso8601String(),
      endDate.toIso8601String(),
    ];
    String walletFilter = '';
    if (walletId != null) {
      walletFilter = 'AND wallet_id = ?';
      args.add(walletId);
    }

    final result = await database.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as total_income,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as total_expense
      FROM transactions
      WHERE date >= ? AND date <= ? $walletFilter
    ''', args);

    return {
      'income': (result.first['total_income'] as num?)?.toDouble() ?? 0,
      'expense': (result.first['total_expense'] as num?)?.toDouble() ?? 0,
    };
  }
}
