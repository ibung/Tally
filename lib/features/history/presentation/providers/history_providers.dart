import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:tally/shared/models/transaction_model.dart';

class HistoryFilterState {
  final String? searchQuery;
  final TransactionType? type;
  final String? walletId;
  final DateTime? startDate;
  final DateTime? endDate;

  const HistoryFilterState({
    this.searchQuery,
    this.type,
    this.walletId,
    this.startDate,
    this.endDate,
  });

  bool get hasActiveFilter =>
      (searchQuery != null && searchQuery!.trim().isNotEmpty) ||
      type != null ||
      walletId != null ||
      startDate != null ||
      endDate != null;

  int get activeFilterCount {
    int count = 0;
    if (searchQuery != null && searchQuery!.trim().isNotEmpty) count++;
    if (type != null) count++;
    if (walletId != null) count++;
    if (startDate != null || endDate != null) count++;
    return count;
  }

  HistoryFilterState copyWith({
    String? searchQuery,
    bool clearSearch = false,
    TransactionType? type,
    bool clearType = false,
    String? walletId,
    bool clearWallet = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
  }) {
    return HistoryFilterState(
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      type: clearType ? null : (type ?? this.type),
      walletId: clearWallet ? null : (walletId ?? this.walletId),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
    );
  }

  HistoryFilterState reset() => const HistoryFilterState();
}

final historyFilterProvider = StateProvider<HistoryFilterState>((ref) {
  return const HistoryFilterState();
});

class HistoryNotifier extends AsyncNotifier<List<TransactionModel>> {
  @override
  Future<List<TransactionModel>> build() async {
    final filter = ref.watch(historyFilterProvider);
    ref.watch(transactionsVersionProvider);
    return _fetchTransactions(filter);
  }

  Future<List<TransactionModel>> _fetchTransactions(HistoryFilterState filter) async {
    final repo = ref.read(transactionRepositoryProvider);
    final startDateStr =
        filter.startDate != null ? DateFormatter.toLocalDate(filter.startDate!) : null;
    final endDateStr =
        filter.endDate != null ? DateFormatter.toLocalDate(filter.endDate!) : null;

    return repo.getAll(
      walletId: filter.walletId,
      type: filter.type?.value,
      startDate: startDateStr,
      endDate: endDateStr,
      searchQuery: filter.searchQuery,
      limit: 300,
    );
  }

  Future<void> refresh() async {
    final filter = ref.read(historyFilterProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchTransactions(filter));
  }
}

final historyTransactionsProvider =
    AsyncNotifierProvider<HistoryNotifier, List<TransactionModel>>(() {
  return HistoryNotifier();
});

/// Ringkasan total transaksi yang sedang tampil pada riwayat
final historySummaryProvider =
    Provider<({int totalIncome, int totalExpense, int count})>((ref) {
  final transactions = ref.watch(historyTransactionsProvider).valueOrNull ?? [];
  int income = 0;
  int expense = 0;

  for (final tx in transactions) {
    if (tx.type == TransactionType.income) {
      income += tx.amount;
    } else if (tx.type == TransactionType.expense) {
      expense += tx.amount;
    }
  }

  return (
    totalIncome: income,
    totalExpense: expense,
    count: transactions.length,
  );
});
