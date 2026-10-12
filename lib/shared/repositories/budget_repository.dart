import 'package:tally/core/database/database_helper.dart';
import 'package:tally/shared/models/budget_model.dart';

class BudgetRepository {
  final DatabaseHelper _db;

  BudgetRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  Future<List<DailyBudgetModel>> getAll({
    bool includeInactive = false,
    String? forLocalDate,
  }) async {
    final database = await _db.database;
    final where = includeInactive ? null : 'is_active = 1';
    final maps = await database.query(
      'daily_budgets',
      where: where,
      orderBy: 'name ASC',
    );

    final list = <DailyBudgetModel>[];
    for (final map in maps) {
      final id = map['id'] as String;
      int spent = 0;
      if (forLocalDate != null) {
        spent = await _calculateSpent(database, id, map, forLocalDate);
      }
      list.add(DailyBudgetModel.fromMap(map, calculatedSpent: spent));
    }
    return list;
  }

  Future<DailyBudgetModel?> getById(String id, {String? forLocalDate}) async {
    final database = await _db.database;
    final maps = await database.query(
      'daily_budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;

    int spent = 0;
    if (forLocalDate != null) {
      spent = await _calculateSpent(database, id, maps.first, forLocalDate);
    }

    return DailyBudgetModel.fromMap(maps.first, calculatedSpent: spent);
  }

  Future<int> _calculateSpent(
    dynamic database,
    String id,
    Map<String, dynamic> map,
    String forLocalDate,
  ) async {
    final periodStr = map['period'] as String? ?? 'daily';
    final period = BudgetPeriod.fromString(periodStr);
    final startDate = map['start_date'] as String? ?? forLocalDate;
    final endDate = map['end_date'] as String?;

    if (period == BudgetPeriod.daily) {
      // Harian: Dihitung per hari untuk tanggal yang sedang dipantau (forLocalDate)
      final spentRes = await database.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) as total
        FROM transactions
        WHERE budget_id = ? AND local_date = ? AND type = 'expense'
          AND (note IS NULL OR LOWER(note) NOT LIKE '%koreksi saldo%')
      ''', [id, forLocalDate]);
      return (spentRes.first['total'] as num?)?.toInt() ?? 0;
    } else {
      // Mingguan & Bulanan: Melacak transaksi pengeluaran dalam rentang tanggal kuota
      List<dynamic> args;
      String dateFilter;
      if (endDate != null && endDate.isNotEmpty) {
        dateFilter = 'local_date >= ? AND local_date <= ?';
        args = [id, startDate, endDate];
      } else {
        dateFilter = 'local_date >= ?';
        args = [id, startDate];
      }

      final spentRes = await database.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) as total
        FROM transactions
        WHERE budget_id = ? AND $dateFilter AND type = 'expense'
          AND (note IS NULL OR LOWER(note) NOT LIKE '%koreksi saldo%')
      ''', args);
      return (spentRes.first['total'] as num?)?.toInt() ?? 0;
    }
  }

  Future<int> insert(DailyBudgetModel budget) async {
    final database = await _db.database;
    return database.insert('daily_budgets', budget.toMap());
  }

  Future<int> update(DailyBudgetModel budget) async {
    final database = await _db.database;
    return database.update(
      'daily_budgets',
      budget.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> setActive(String id, bool isActive) async {
    final database = await _db.database;
    return database.update(
      'daily_budgets',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(String id) async {
    final database = await _db.database;
    return database.delete('daily_budgets', where: 'id = ?', whereArgs: [id]);
  }
}
