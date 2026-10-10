import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/shared/models/budget_model.dart';
import 'package:tally/shared/repositories/budget_repository.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository();
});

/// Tanggal lokal acuan untuk memantau kuota (default: hari ini)
final selectedDateForBudgetsProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

class BudgetsNotifier extends AsyncNotifier<List<DailyBudgetModel>> {
  static const _uuid = Uuid();

  @override
  Future<List<DailyBudgetModel>> build() async {
    final date = ref.watch(selectedDateForBudgetsProvider);
    final localDate = DateFormatter.toLocalDate(date);
    return _fetchBudgets(localDate);
  }

  Future<List<DailyBudgetModel>> _fetchBudgets(String localDate) async {
    final repo = ref.read(budgetRepositoryProvider);
    return repo.getAll(includeInactive: true, forLocalDate: localDate);
  }

  Future<void> refresh() async {
    final date = ref.read(selectedDateForBudgetsProvider);
    final localDate = DateFormatter.toLocalDate(date);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchBudgets(localDate));
  }

  Future<void> createBudget({
    required String name,
    required int dailyLimit,
    String? startDate,
    String? endDate,
  }) async {
    final repo = ref.read(budgetRepositoryProvider);
    final now = DateTime.now();
    final defaultStartDate = startDate ?? DateFormatter.toLocalDate(now);

    final budget = DailyBudgetModel(
      id: _uuid.v4(),
      name: name.trim(),
      dailyLimit: dailyLimit,
      startDate: defaultStartDate,
      endDate: endDate,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    await repo.insert(budget);
    await refresh();
  }

  Future<void> updateBudget({
    required String id,
    required String name,
    required int dailyLimit,
    String? startDate,
    String? endDate,
  }) async {
    final repo = ref.read(budgetRepositoryProvider);
    final current = state.valueOrNull?.firstWhere((b) => b.id == id);
    if (current == null) return;

    final updated = current.copyWith(
      name: name.trim(),
      dailyLimit: dailyLimit,
      startDate: startDate ?? current.startDate,
      endDate: endDate,
      updatedAt: DateTime.now(),
    );

    await repo.update(updated);
    await refresh();
  }

  Future<void> toggleActive(String id, bool isActive) async {
    final repo = ref.read(budgetRepositoryProvider);
    await repo.setActive(id, isActive);
    await refresh();
  }

  Future<void> deleteBudget(String id) async {
    final repo = ref.read(budgetRepositoryProvider);
    await repo.delete(id);
    await refresh();
  }
}

final budgetsProvider = AsyncNotifierProvider<BudgetsNotifier, List<DailyBudgetModel>>(() {
  return BudgetsNotifier();
});

/// Ringkasan total kuota dan penggunaan hari ini dari seluruh kuota aktif
final dailyBudgetSummaryProvider = Provider<({int totalLimit, int totalSpent, int remaining})>((ref) {
  final budgets = ref.watch(budgetsProvider).valueOrNull ?? [];
  final activeBudgets = budgets.where((b) => b.isActive).toList();

  final totalLimit = activeBudgets.fold<int>(0, (sum, b) => sum + b.dailyLimit);
  final totalSpent = activeBudgets.fold<int>(0, (sum, b) => sum + b.spent);
  final remaining = totalLimit - totalSpent;

  return (
    totalLimit: totalLimit,
    totalSpent: totalSpent,
    remaining: remaining,
  );
});
