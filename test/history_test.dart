import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tally/features/history/presentation/history_screen.dart';
import 'package:tally/features/history/presentation/providers/history_providers.dart';
import 'package:tally/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:tally/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:tally/shared/models/transaction_model.dart';
import 'package:tally/shared/models/wallet_model.dart';
import 'package:tally/shared/repositories/transaction_repository.dart';
import 'package:tally/shared/repositories/wallet_repository.dart';

// Fake Transaction Repository for History Tests
class FakeHistoryTransactionRepository implements TransactionRepository {
  final List<TransactionModel> _transactions = [];

  void addTx(TransactionModel tx) => _transactions.add(tx);

  @override
  Future<List<TransactionModel>> getAll({
    String? walletId,
    String? type,
    String? localDate,
    String? startDate,
    String? endDate,
    String? searchQuery,
    int limit = 100,
    int offset = 0,
  }) async {
    var result = List<TransactionModel>.from(_transactions);

    if (walletId != null) {
      result = result
          .where((t) =>
              t.walletId == walletId ||
              t.sourceWalletId == walletId ||
              t.destinationWalletId == walletId)
          .toList();
    }
    if (type != null) {
      result = result.where((t) => t.type.value == type).toList();
    }
    if (localDate != null) {
      result = result.where((t) => t.localDate == localDate).toList();
    }
    if (startDate != null) {
      result = result.where((t) => t.localDate.compareTo(startDate) >= 0).toList();
    }
    if (endDate != null) {
      result = result.where((t) => t.localDate.compareTo(endDate) <= 0).toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((t) {
        final noteMatch = t.note?.toLowerCase().contains(q) ?? false;
        final catMatch = t.categoryName?.toLowerCase().contains(q) ?? false;
        final walletMatch = t.walletName?.toLowerCase().contains(q) ?? false;
        return noteMatch || catMatch || walletMatch;
      }).toList();
    }

    result.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return result;
  }

  @override
  Future<TransactionModel?> getById(String id) async {
    try {
      return _transactions.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> insert(TransactionModel transaction) async {
    _transactions.add(transaction);
    return 1;
  }

  @override
  Future<int> update(TransactionModel transaction) async {
    final idx = _transactions.indexWhere((t) => t.id == transaction.id);
    if (idx != -1) {
      _transactions[idx] = transaction;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> delete(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    return 1;
  }

  @override
  Future<({int income, int expense})> getDailySummary(String localDate) async =>
      (income: 0, expense: 0);

  @override
  Future<int> getBudgetSpentForDate(String budgetId, String localDate) async => 0;

  @override
  Future<int> getHistoricalEndBalance(String localDate) async => 0;
}

// Fake Wallet Repository
class FakeHistoryWalletRepository implements WalletRepository {
  final List<WalletModel> _wallets = [];

  void addWallet(WalletModel wallet) => _wallets.add(wallet);

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
  Future<int> archive(String id, {bool archived = true}) async => 1;

  @override
  Future<int> delete(String id) async => 1;

  @override
  Future<int> getWalletBalance(String walletId) async => 500000;

  @override
  Future<int> getTotalBalance() async => 500000;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  late FakeHistoryTransactionRepository fakeRepo;
  late FakeHistoryWalletRepository fakeWalletRepo;

  setUp(() {
    fakeRepo = FakeHistoryTransactionRepository();
    fakeWalletRepo = FakeHistoryWalletRepository();
  });

  group('HistoryFilterState Unit Tests', () {
    test('Default filter state has no active filters', () {
      const state = HistoryFilterState();
      expect(state.hasActiveFilter, false);
      expect(state.activeFilterCount, 0);
    });

    test('Adding filters updates hasActiveFilter and activeFilterCount', () {
      final state = const HistoryFilterState().copyWith(
        searchQuery: 'Makan',
        type: TransactionType.expense,
      );
      expect(state.hasActiveFilter, true);
      expect(state.activeFilterCount, 2);

      final resetState = state.reset();
      expect(resetState.hasActiveFilter, false);
    });
  });

  group('History Summary & Filtering Tests', () {
    test('Calculates totalIncome, totalExpense, and count correctly', () async {
      fakeRepo.addTx(TransactionModel(
        id: 'tx-1',
        type: TransactionType.income,
        amount: 500000,
        occurredAt: DateTime(2026, 10, 10, 10, 0),
        localDate: '2026-10-10',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      fakeRepo.addTx(TransactionModel(
        id: 'tx-2',
        type: TransactionType.expense,
        amount: 150000,
        occurredAt: DateTime(2026, 10, 10, 12, 0),
        localDate: '2026-10-10',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      fakeRepo.addTx(TransactionModel(
        id: 'tx-3',
        type: TransactionType.expense,
        amount: 50000,
        occurredAt: DateTime(2026, 10, 9, 8, 0),
        localDate: '2026-10-09',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final list = await container.read(historyTransactionsProvider.future);
      expect(list.length, 3);

      final summary = container.read(historySummaryProvider);
      expect(summary.count, 3);
      expect(summary.totalIncome, 500000);
      expect(summary.totalExpense, 200000);
    });

    test('Filtering by search query returns matching results', () async {
      fakeRepo.addTx(TransactionModel(
        id: 'tx-1',
        type: TransactionType.expense,
        amount: 25000,
        categoryName: 'Kopi Kenangan',
        note: 'Beli kopi americano',
        occurredAt: DateTime(2026, 10, 10),
        localDate: '2026-10-10',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      fakeRepo.addTx(TransactionModel(
        id: 'tx-2',
        type: TransactionType.expense,
        amount: 50000,
        categoryName: 'Bensin',
        occurredAt: DateTime(2026, 10, 10),
        localDate: '2026-10-10',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      container.read(historyFilterProvider.notifier).state =
          const HistoryFilterState(searchQuery: 'kopi');

      final results = await container.read(historyTransactionsProvider.future);
      expect(results.length, 1);
      expect(results.first.categoryName, 'Kopi Kenangan');
    });
  });

  group('HistoryScreen Widget Tests', () {
    testWidgets('Renders search bar, filter chips, summary strip, and grouped items',
        (tester) async {
      fakeRepo.addTx(TransactionModel(
        id: 'tx-1',
        type: TransactionType.expense,
        amount: 30000,
        categoryName: 'Makan Malam',
        walletName: 'Tunai',
        occurredAt: DateTime(2026, 10, 10, 19, 0),
        localDate: '2026-10-10',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      fakeWalletRepo.addWallet(WalletModel(
        id: 'w-1',
        name: 'Tunai',
        openingBalance: 100000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeRepo),
          walletRepositoryProvider.overrideWithValue(fakeWalletRepo),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check search input
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cari catatan, kategori, dompet...'), findsOneWidget);

      // Check quick chips
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.text('Pemasukan'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);

      // Check summary strip
      expect(find.text('1 Transaksi'), findsOneWidget);

      // Check transaction item
      expect(find.text('Makan Malam'), findsOneWidget);
      expect(find.text('-Rp 30.000'), findsWidgets);
    });

    testWidgets('Tapping quick filter chip switches type filter', (tester) async {
      fakeRepo.addTx(TransactionModel(
        id: 'tx-1',
        type: TransactionType.income,
        amount: 100000,
        categoryName: 'Gaji',
        occurredAt: DateTime(2026, 10, 10),
        localDate: '2026-10-10',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      fakeRepo.addTx(TransactionModel(
        id: 'tx-2',
        type: TransactionType.expense,
        amount: 50000,
        categoryName: 'Belanja',
        occurredAt: DateTime(2026, 10, 10),
        localDate: '2026-10-10',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeRepo),
          walletRepositoryProvider.overrideWithValue(fakeWalletRepo),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially shows both
      expect(find.text('Gaji'), findsOneWidget);
      expect(find.text('Belanja'), findsOneWidget);

      // Tap 'Pengeluaran' chip
      await tester.tap(find.text('Pengeluaran'));
      await tester.pumpAndSettle();

      // Should only show Belanja
      expect(find.text('Belanja'), findsOneWidget);
      expect(find.text('Gaji'), findsNothing);
    });
  });
}
