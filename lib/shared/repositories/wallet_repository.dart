import 'package:tally/core/database/database_helper.dart';
import 'package:tally/shared/models/wallet_model.dart';

class WalletRepository {
  final DatabaseHelper _db;

  WalletRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  Future<List<WalletModel>> getAll() async {
    final database = await _db.database;
    final maps = await database.query('wallets', orderBy: 'name ASC');
    return maps.map(WalletModel.fromMap).toList();
  }

  Future<WalletModel?> getById(int id) async {
    final database = await _db.database;
    final maps = await database.query(
      'wallets',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return WalletModel.fromMap(maps.first);
  }

  Future<int> insert(WalletModel wallet) async {
    final database = await _db.database;
    return database.insert('wallets', wallet.toMap());
  }

  Future<int> update(WalletModel wallet) async {
    final database = await _db.database;
    return database.update(
      'wallets',
      wallet.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [wallet.id],
    );
  }

  Future<int> delete(int id) async {
    final database = await _db.database;
    return database.delete('wallets', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalBalance() async {
    final database = await _db.database;
    final result = await database.rawQuery(
      'SELECT SUM(balance) as total FROM wallets',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }
}
