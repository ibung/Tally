import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tally/shared/models/wallet_model.dart';
import 'package:tally/shared/repositories/wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository();
});

class WalletsNotifier extends AsyncNotifier<List<WalletModel>> {
  static const _uuid = Uuid();

  @override
  Future<List<WalletModel>> build() async {
    return _fetchWallets();
  }

  Future<List<WalletModel>> _fetchWallets({bool includeArchived = true}) async {
    final repo = ref.read(walletRepositoryProvider);
    return repo.getAll(includeArchived: includeArchived);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchWallets());
  }

  Future<void> createWallet({
    required String name,
    required String type,
    required int openingBalance,
    String? icon,
    String? color,
  }) async {
    final repo = ref.read(walletRepositoryProvider);
    final now = DateTime.now();
    final wallet = WalletModel(
      id: _uuid.v4(),
      name: name.trim(),
      type: type,
      openingBalance: openingBalance,
      currentBalance: openingBalance,
      icon: icon,
      color: color,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    await repo.insert(wallet);
    await refresh();
  }

  Future<void> updateWallet({
    required String id,
    required String name,
    required String type,
    required int openingBalance,
    String? icon,
    String? color,
  }) async {
    final repo = ref.read(walletRepositoryProvider);
    final current = state.valueOrNull?.firstWhere((w) => w.id == id);
    if (current == null) return;

    final updated = current.copyWith(
      name: name.trim(),
      type: type,
      openingBalance: openingBalance,
      icon: icon,
      color: color,
      updatedAt: DateTime.now(),
    );

    await repo.update(updated);
    await refresh();
  }

  Future<void> toggleArchive(String id, bool archived) async {
    final repo = ref.read(walletRepositoryProvider);
    await repo.archive(id, archived: archived);
    await refresh();
  }

  Future<void> deleteWallet(String id) async {
    final repo = ref.read(walletRepositoryProvider);
    await repo.delete(id);
    await refresh();
  }
}

final walletsProvider = AsyncNotifierProvider<WalletsNotifier, List<WalletModel>>(() {
  return WalletsNotifier();
});

/// Total saldo dari seluruh wallet aktif saat ini
final totalActiveBalanceProvider = Provider<int>((ref) {
  final wallets = ref.watch(walletsProvider).valueOrNull ?? [];
  return wallets
      .where((w) => !w.isArchived)
      .fold<int>(0, (sum, w) => sum + w.currentBalance);
});
