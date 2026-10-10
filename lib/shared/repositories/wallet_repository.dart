import 'package:tally/core/database/database_helper.dart';
import 'package:tally/shared/models/wallet_model.dart';

class WalletRepository {
  final DatabaseHelper _db;

  WalletRepository({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  Future<List<WalletModel>> getAll({bool includeArchived = false}) async {
    final database = await _db.database;
    final where = includeArchived ? null : 'is_archived = 0';
    final maps = await database.query(
      'wallets',
      where: where,
      orderBy: 'name ASC',
    );

    // Calculate dynamic balance for each wallet (PRD Bab 7)
    final list = <WalletModel>[];
    for (final map in maps) {
      final walletId = map['id'] as String;
      final balance = await getWalletBalance(walletId);
      list.add(WalletModel.fromMap(map, calculatedBalance: balance));
    }
    return list;
  }

  Future<WalletModel?> getById(String id) async {
    final database = await _db.database;
    final maps = await database.query(
      'wallets',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    final balance = await getWalletBalance(id);
    return WalletModel.fromMap(maps.first, calculatedBalance: balance);
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

  Future<int> archive(String id, {bool archived = true}) async {
    final database = await _db.database;
    return database.update(
      'wallets',
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
    return database.delete('wallets', where: 'id = ?', whereArgs: [id]);
  }

  /// Menghitung saldo wallet secara akurat sesuai PRD Bab 7:
  /// Saldo = saldo awal + pemasukan - pengeluaran + transfer masuk - transfer keluar
  Future<int> getWalletBalance(String walletId) async {
    final database = await _db.database;

    // 1. Saldo awal
    final walletMaps = await database.query(
      'wallets',
      columns: ['opening_balance'],
      where: 'id = ?',
      whereArgs: [walletId],
    );
    if (walletMaps.isEmpty) return 0;
    final openingBalance = (walletMaps.first['opening_balance'] as num?)?.toInt() ?? 0;

    // 2. Pemasukan (wallet_id = ?)
    final incomeRes = await database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM transactions
      WHERE wallet_id = ? AND type = 'income'
    ''', [walletId]);
    final totalIncome = (incomeRes.first['total'] as num?)?.toInt() ?? 0;

    // 3. Pengeluaran (wallet_id = ?)
    final expenseRes = await database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM transactions
      WHERE wallet_id = ? AND type = 'expense'
    ''', [walletId]);
    final totalExpense = (expenseRes.first['total'] as num?)?.toInt() ?? 0;

    // 4. Transfer Masuk (destination_wallet_id = ?)
    final transferInRes = await database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM transactions
      WHERE destination_wallet_id = ? AND type = 'transfer'
    ''', [walletId]);
    final totalTransferIn = (transferInRes.first['total'] as num?)?.toInt() ?? 0;

    // 5. Transfer Keluar (source_wallet_id = ?)
    final transferOutRes = await database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM transactions
      WHERE source_wallet_id = ? AND type = 'transfer'
    ''', [walletId]);
    final totalTransferOut = (transferOutRes.first['total'] as num?)?.toInt() ?? 0;

    return openingBalance + totalIncome - totalExpense + totalTransferIn - totalTransferOut;
  }

  /// Menghitung total saldo seluruh wallet aktif saat ini
  Future<int> getTotalBalance() async {
    final wallets = await getAll(includeArchived: false);
    return wallets.fold<int>(0, (sum, w) => sum + w.currentBalance);
  }
}
