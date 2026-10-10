import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:tally/shared/models/wallet_model.dart';
import 'package:tally/shared/repositories/wallet_repository.dart';

// Fake in-memory repository for unit testing
class FakeWalletRepository implements WalletRepository {
  final List<WalletModel> _wallets = [];

  @override
  Future<List<WalletModel>> getAll({bool includeArchived = false}) async {
    if (includeArchived) return List.from(_wallets);
    return _wallets.where((w) => !w.isArchived).toList();
  }

  @override
  Future<WalletModel?> getById(String id) async {
    try {
      return _wallets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> insert(WalletModel wallet) async {
    _wallets.add(wallet);
    return 1;
  }

  @override
  Future<int> update(WalletModel wallet) async {
    final idx = _wallets.indexWhere((w) => w.id == wallet.id);
    if (idx != -1) {
      _wallets[idx] = wallet;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> archive(String id, {bool archived = true}) async {
    final idx = _wallets.indexWhere((w) => w.id == id);
    if (idx != -1) {
      _wallets[idx] = _wallets[idx].copyWith(isArchived: archived);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> delete(String id) async {
    _wallets.removeWhere((w) => w.id == id);
    return 1;
  }

  @override
  Future<int> getWalletBalance(String walletId) async {
    final w = await getById(walletId);
    return w?.currentBalance ?? 0;
  }

  @override
  Future<int> getTotalBalance() async {
    final list = await getAll(includeArchived: false);
    return list.fold<int>(0, (sum, w) => sum + w.currentBalance);
  }
}

void main() {
  group('Wallets Provider Unit Tests', () {
    late FakeWalletRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeWalletRepository();
      container = ProviderContainer(
        overrides: [
          walletRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial wallets list is empty and total balance is 0', () async {
      final wallets = await container.read(walletsProvider.future);
      expect(wallets, isEmpty);
      expect(container.read(totalActiveBalanceProvider), 0);
    });

    test('Creating a wallet adds it to the list and updates total balance', () async {
      await container.read(walletsProvider.notifier).createWallet(
            name: 'BCA',
            type: 'bank',
            openingBalance: 500000,
          );

      final wallets = await container.read(walletsProvider.future);
      expect(wallets.length, 1);
      expect(wallets.first.name, 'BCA');
      expect(wallets.first.type, 'bank');
      expect(wallets.first.currentBalance, 500000);
      expect(container.read(totalActiveBalanceProvider), 500000);
    });

    test('Archived wallet is excluded from total balance calculation', () async {
      await container.read(walletsProvider.notifier).createWallet(
            name: 'Dompet 1',
            type: 'cash',
            openingBalance: 100000,
          );
      await container.read(walletsProvider.notifier).createWallet(
            name: 'Dompet 2',
            type: 'cash',
            openingBalance: 200000,
          );

      var wallets = await container.read(walletsProvider.future);
      expect(container.read(totalActiveBalanceProvider), 300000);

      // Archive Dompet 2
      final wallet2Id = wallets.firstWhere((w) => w.name == 'Dompet 2').id;
      await container.read(walletsProvider.notifier).toggleArchive(wallet2Id, true);

      wallets = await container.read(walletsProvider.future);
      expect(wallets.firstWhere((w) => w.id == wallet2Id).isArchived, true);
      // Only Dompet 1 counts towards active balance
      expect(container.read(totalActiveBalanceProvider), 100000);
    });

    test('Updating a wallet modifies its attributes', () async {
      await container.read(walletsProvider.notifier).createWallet(
            name: 'Lama',
            type: 'cash',
            openingBalance: 50000,
          );

      final walletId = (await container.read(walletsProvider.future)).first.id;
      await container.read(walletsProvider.notifier).updateWallet(
            id: walletId,
            name: 'Baru',
            type: 'e-wallet',
            openingBalance: 75000,
          );

      final updated = (await container.read(walletsProvider.future)).first;
      expect(updated.name, 'Baru');
      expect(updated.type, 'e-wallet');
      expect(updated.openingBalance, 75000);
    });
  });
}
