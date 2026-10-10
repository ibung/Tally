import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/budgets/presentation/providers/budget_providers.dart';
import 'package:tally/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:tally/shared/models/transaction_model.dart';
import 'package:tally/shared/repositories/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

/// Tanggal terpilih untuk filter transaksi dashboard
final selectedTransactionDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

class TransactionsNotifier extends AsyncNotifier<List<TransactionModel>> {
  static const _uuid = Uuid();

  @override
  Future<List<TransactionModel>> build() async {
    final date = ref.watch(selectedTransactionDateProvider);
    final localDate = DateFormatter.toLocalDate(date);
    return _fetchTransactions(localDate);
  }

  Future<List<TransactionModel>> _fetchTransactions(String localDate) async {
    final repo = ref.read(transactionRepositoryProvider);
    return repo.getAll(localDate: localDate);
  }

  Future<void> refresh() async {
    final date = ref.read(selectedTransactionDateProvider);
    final localDate = DateFormatter.toLocalDate(date);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchTransactions(localDate));
  }

  Future<void> createTransaction({
    required TransactionType type,
    required int amount,
    String? categoryId,
    String? walletId,
    String? sourceWalletId,
    String? destinationWalletId,
    String? budgetId,
    required DateTime occurredAt,
    String? note,
  }) async {
    final repo = ref.read(transactionRepositoryProvider);
    final now = DateTime.now();
    final localDate = DateFormatter.toLocalDate(occurredAt);

    final tx = TransactionModel(
      id: _uuid.v4(),
      type: type,
      amount: amount,
      categoryId: categoryId,
      walletId: walletId,
      sourceWalletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      budgetId: budgetId,
      occurredAt: occurredAt,
      localDate: localDate,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await repo.insert(tx);

    // Refresh transactions, wallets balance, dan daily budgets
    await refresh();
    ref.read(walletsProvider.notifier).refresh();
    ref.read(budgetsProvider.notifier).refresh();
  }

  Future<void> updateTransaction({
    required String id,
    required TransactionType type,
    required int amount,
    String? categoryId,
    String? walletId,
    String? sourceWalletId,
    String? destinationWalletId,
    String? budgetId,
    required DateTime occurredAt,
    String? note,
  }) async {
    final repo = ref.read(transactionRepositoryProvider);
    final localDate = DateFormatter.toLocalDate(occurredAt);

    final current = await repo.getById(id);
    if (current == null) return;

    final updated = current.copyWith(
      type: type,
      amount: amount,
      categoryId: categoryId,
      walletId: walletId,
      sourceWalletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      budgetId: budgetId,
      occurredAt: occurredAt,
      localDate: localDate,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      updatedAt: DateTime.now(),
    );

    await repo.update(updated);

    // Refresh state
    await refresh();
    ref.read(walletsProvider.notifier).refresh();
    ref.read(budgetsProvider.notifier).refresh();
  }

  Future<void> deleteTransaction(String id) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.delete(id);

    // Refresh state
    await refresh();
    ref.read(walletsProvider.notifier).refresh();
    ref.read(budgetsProvider.notifier).refresh();
  }
}

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<TransactionModel>>(() {
  return TransactionsNotifier();
});

/// Ringkasan Pemasukan & Pengeluaran pada tanggal terpilih
final dailySummaryProvider = FutureProvider<({int income, int expense})>((ref) async {
  final date = ref.watch(selectedTransactionDateProvider);
  ref.watch(transactionsProvider);
  final localDate = DateFormatter.toLocalDate(date);
  final repo = ref.read(transactionRepositoryProvider);
  return repo.getDailySummary(localDate);
});

/// Saldo Akhir Historis pada tanggal terpilih (PRD Bab 7)
final historicalEndBalanceProvider = FutureProvider<int>((ref) async {
  final date = ref.watch(selectedTransactionDateProvider);
  ref.watch(transactionsProvider);
  final localDate = DateFormatter.toLocalDate(date);
  final repo = ref.read(transactionRepositoryProvider);
  return repo.getHistoricalEndBalance(localDate);
});

