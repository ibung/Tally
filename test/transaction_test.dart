import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:tally/shared/models/transaction_model.dart';
import 'package:tally/shared/repositories/transaction_repository.dart';

// Fake in-memory repository for transactions
class FakeTransactionRepository implements TransactionRepository {
  final List<TransactionModel> _transactions = [];

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
  Future<({int income, int expense})> getDailySummary(String localDate) async {
    final forDate = _transactions.where((t) => t.localDate == localDate);
    final inc = forDate
        .where((t) => t.type == TransactionType.income)
        .fold<int>(0, (sum, t) => sum + t.amount);
    final exp = forDate
        .where((t) => t.type == TransactionType.expense)
        .fold<int>(0, (sum, t) => sum + t.amount);
    return (income: inc, expense: exp);
  }

  @override
  Future<int> getBudgetSpentForDate(String budgetId, String localDate) async {
    return _transactions
        .where((t) =>
            t.budgetId == budgetId &&
            t.localDate == localDate &&
            t.type == TransactionType.expense)
        .fold<int>(0, (sum, t) => sum + t.amount);
  }

  @override
  Future<int> getHistoricalEndBalance(String localDate) async {
    final untilDate = _transactions.where((t) => t.localDate.compareTo(localDate) <= 0);
    final inc = untilDate
        .where((t) => t.type == TransactionType.income)
        .fold<int>(0, (sum, t) => sum + t.amount);
    final exp = untilDate
        .where((t) => t.type == TransactionType.expense)
        .fold<int>(0, (sum, t) => sum + t.amount);
    return inc - exp;
  }
}

void main() {
  group('Transactions Provider Unit Tests', () {
    late FakeTransactionRepository fakeRepo;
    late ProviderContainer container;
    final testDate = DateTime(2026, 10, 10, 12, 0);

    setUp(() {
      fakeRepo = FakeTransactionRepository();
      container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeRepo),
          selectedTransactionDateProvider.overrideWith((ref) => testDate),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial transactions list is empty', () async {
      final txs = await container.read(transactionsProvider.future);
      expect(txs, isEmpty);
    });

    test('Creating an expense transaction records it and updates daily summary', () async {
      await container.read(transactionsProvider.notifier).createTransaction(
            type: TransactionType.expense,
            amount: 25000,
            walletId: 'wallet-1',
            budgetId: 'budget-1',
            occurredAt: testDate,
            note: 'Makan siang',
          );

      final txs = await container.read(transactionsProvider.future);
      expect(txs.length, 1);
      expect(txs.first.type, TransactionType.expense);
      expect(txs.first.amount, 25000);
      expect(txs.first.walletId, 'wallet-1');
      expect(txs.first.budgetId, 'budget-1');
      expect(txs.first.note, 'Makan siang');

      final summary = await container.read(dailySummaryProvider.future);
      expect(summary.expense, 25000);
      expect(summary.income, 0);
    });

    test('Creating an income transaction updates daily summary correctly', () async {
      await container.read(transactionsProvider.notifier).createTransaction(
            type: TransactionType.income,
            amount: 100000,
            walletId: 'wallet-1',
            occurredAt: testDate,
            note: 'Gaji',
          );

      final summary = await container.read(dailySummaryProvider.future);
      expect(summary.income, 100000);
      expect(summary.expense, 0);
    });

    test('Transfer transaction does not affect income or expense in daily summary', () async {
      await container.read(transactionsProvider.notifier).createTransaction(
            type: TransactionType.transfer,
            amount: 50000,
            sourceWalletId: 'wallet-1',
            destinationWalletId: 'wallet-2',
            occurredAt: testDate,
            note: 'Transfer BCA ke GoPay',
          );

      final txs = await container.read(transactionsProvider.future);
      expect(txs.length, 1);
      expect(txs.first.type, TransactionType.transfer);
      expect(txs.first.sourceWalletId, 'wallet-1');
      expect(txs.first.destinationWalletId, 'wallet-2');

      // PRD Bab 7: Transfer tidak dihitung sebagai pemasukan atau pengeluaran
      final summary = await container.read(dailySummaryProvider.future);
      expect(summary.income, 0);
      expect(summary.expense, 0);
    });

    test('Updating a transaction updates its amount and details', () async {
      await container.read(transactionsProvider.notifier).createTransaction(
            type: TransactionType.expense,
            amount: 20000,
            walletId: 'wallet-1',
            occurredAt: testDate,
          );

      final txId = (await container.read(transactionsProvider.future)).first.id;
      await container.read(transactionsProvider.notifier).updateTransaction(
            id: txId,
            type: TransactionType.expense,
            amount: 30000,
            walletId: 'wallet-1',
            occurredAt: testDate,
            note: 'Updated note',
          );

      final updated = (await container.read(transactionsProvider.future)).first;
      expect(updated.amount, 30000);
      expect(updated.note, 'Updated note');
    });

    test('Deleting a transaction removes it from the list', () async {
      await container.read(transactionsProvider.notifier).createTransaction(
            type: TransactionType.expense,
            amount: 20000,
            walletId: 'wallet-1',
            occurredAt: testDate,
          );

      var txs = await container.read(transactionsProvider.future);
      expect(txs.length, 1);

      await container.read(transactionsProvider.notifier).deleteTransaction(txs.first.id);

      txs = await container.read(transactionsProvider.future);
      expect(txs, isEmpty);
    });
  });
}
