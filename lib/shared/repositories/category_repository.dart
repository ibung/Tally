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
}
