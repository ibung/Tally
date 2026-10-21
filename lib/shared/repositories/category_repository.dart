import 'package:tally/core/database/database_helper.dart';
import 'package:tally/shared/models/category_model.dart';

class CategoryRepository {
  final DatabaseHelper _db;

  CategoryRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  Future<List<CategoryModel>> getAll({
    CategoryType? type,
    bool includeArchived = false,
  }) async {
    final database = await _db.database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (!includeArchived) {
      conditions.add('is_archived = 0');
    }
    if (type != null) {
      conditions.add('type = ?');
      args.add(type.value);
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final maps = await database.query(
      'categories',
      where: where,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'name ASC',
    );

    return maps.map(CategoryModel.fromMap).toList();
  }

  Future<CategoryModel?> getById(String id) async {
    final database = await _db.database;
    final maps = await database.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return CategoryModel.fromMap(maps.first);
  }

  Future<int> insert(CategoryModel category) async {
    final database = await _db.database;
    return database.insert('categories', category.toMap());
  }

  Future<int> update(CategoryModel category) async {
    final database = await _db.database;
    return database.update(
      'categories',
      category.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> archive(String id, {bool archived = true}) async {
    final database = await _db.database;
    return database.update(
      'categories',
      {
        'is_archived': archived ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(String id) async {
    final database = await _db.database;
    return database.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  /// Mengambil rincian pengeluaran/pemasukan per kategori untuk grafik analisis.
  Future<List<CategoryChartItem>> getCategoryBreakdown({
    required CategoryType type,
    String? startDate,
    String? endDate,
  }) async {
    final database = await _db.database;
    final conditions = <String>[
      't.type = ?',
      "(t.note IS NULL OR LOWER(t.note) NOT LIKE '%koreksi saldo%')",
    ];
    final args = <dynamic>[type.value];

    if (startDate != null) {
      conditions.add('t.local_date >= ?');
      args.add(startDate);
    }
    if (endDate != null) {
      conditions.add('t.local_date <= ?');
      args.add(endDate);
    }

    final where = 'WHERE ${conditions.join(' AND ')}';

    final rows = await database.rawQuery('''
      SELECT 
        COALESCE(c.id, 'uncategorized') as category_id,
        COALESCE(c.name, 'Tanpa Kategori') as category_name,
        COALESCE(c.icon, 'other') as category_icon,
        COALESCE(c.color, '#0A0A0A') as category_color,
        COALESCE(SUM(t.amount), 0) as total_amount,
        COUNT(t.id) as transaction_count
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      $where
      GROUP BY t.category_id
      HAVING total_amount > 0
      ORDER BY total_amount DESC
    ''', args);

    if (rows.isEmpty) return [];

    final grandTotal = rows.fold<int>(
      0,
      (sum, r) => sum + ((r['total_amount'] as num?)?.toInt() ?? 0),
    );

    return rows.map((r) {
      final amount = (r['total_amount'] as num?)?.toInt() ?? 0;
      final pct = grandTotal > 0 ? (amount / grandTotal) : 0.0;
      return CategoryChartItem(
        categoryId: r['category_id'] as String,
        categoryName: r['category_name'] as String,
        categoryIcon: r['category_icon'] as String,
        categoryColor: r['category_color'] as String,
        type: type,
        totalAmount: amount,
        transactionCount: (r['transaction_count'] as num?)?.toInt() ?? 0,
        percentage: pct,
      );
    }).toList();
  }
}
