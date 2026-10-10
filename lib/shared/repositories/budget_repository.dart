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
        final spentRes = await database.rawQuery('''
          SELECT COALESCE(SUM(amount), 0) as total
          FROM transactions
          WHERE budget_id = ? AND local_date = ? AND type = 'expense'
        ''', [id, forLocalDate]);
        spent = (spentRes.first['total'] as num?)?.toInt() ?? 0;
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
      final spentRes = await database.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) as total
        FROM transactions
        WHERE budget_id = ? AND local_date = ? AND type = 'expense'
      ''', [id, forLocalDate]);
      spent = (spentRes.first['total'] as num?)?.toInt() ?? 0;
    }

    return DailyBudgetModel.fromMap(maps.first, calculatedSpent: spent);
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
