import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/features/budgets/presentation/providers/budget_providers.dart';
import 'package:tally/shared/models/budget_model.dart';
import 'package:tally/shared/repositories/budget_repository.dart';

// Fake in-memory repository for daily budget unit testing
class FakeBudgetRepository implements BudgetRepository {
  final List<DailyBudgetModel> _budgets = [];

  @override
  Future<List<DailyBudgetModel>> getAll({
    bool includeInactive = false,
    String? forLocalDate,
  }) async {
    if (includeInactive) return List.from(_budgets);
    return _budgets.where((b) => b.isActive).toList();
  }

  @override
  Future<DailyBudgetModel?> getById(String id, {String? forLocalDate}) async {
    try {
      return _budgets.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> insert(DailyBudgetModel budget) async {
    _budgets.add(budget);
    return 1;
  }

  @override
  Future<int> update(DailyBudgetModel budget) async {
    final idx = _budgets.indexWhere((b) => b.id == budget.id);
    if (idx != -1) {
      _budgets[idx] = budget;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> setActive(String id, bool isActive) async {
    final idx = _budgets.indexWhere((b) => b.id == id);
    if (idx != -1) {
      _budgets[idx] = _budgets[idx].copyWith(isActive: isActive);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> delete(String id) async {
    _budgets.removeWhere((b) => b.id == id);
    return 1;
  }
}

void main() {
  group('Daily Budgets Provider Unit Tests', () {
    late FakeBudgetRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeBudgetRepository();
      container = ProviderContainer(
        overrides: [
          budgetRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial budgets list is empty and summary is 0', () async {
      final budgets = await container.read(budgetsProvider.future);
      expect(budgets, isEmpty);

      final summary = container.read(dailyBudgetSummaryProvider);
      expect(summary.totalLimit, 0);
      expect(summary.totalSpent, 0);
      expect(summary.remaining, 0);
    });

    test('Creating a daily budget adds it to the list and updates summary', () async {
      await container.read(budgetsProvider.notifier).createBudget(
            name: 'Makan',
            dailyLimit: 50000,
          );

      final budgets = await container.read(budgetsProvider.future);
      expect(budgets.length, 1);
      expect(budgets.first.name, 'Makan');
      expect(budgets.first.dailyLimit, 50000);
      expect(budgets.first.isActive, true);

      final summary = container.read(dailyBudgetSummaryProvider);
      expect(summary.totalLimit, 50000);
      expect(summary.totalSpent, 0);
      expect(summary.remaining, 50000);
    });

    test('Inactive budget is excluded from summary calculation', () async {
      await container.read(budgetsProvider.notifier).createBudget(
            name: 'Makan',
            dailyLimit: 50000,
          );
      await container.read(budgetsProvider.notifier).createBudget(
            name: 'Kopi',
            dailyLimit: 25000,
          );

      var budgets = await container.read(budgetsProvider.future);
      expect(container.read(dailyBudgetSummaryProvider).totalLimit, 75000);

      // Deactivate Kopi
      final kopiId = budgets.firstWhere((b) => b.name == 'Kopi').id;
      await container.read(budgetsProvider.notifier).toggleActive(kopiId, false);

      budgets = await container.read(budgetsProvider.future);
      expect(budgets.firstWhere((b) => b.id == kopiId).isActive, false);

      // Only Makan is active
      final summary = container.read(dailyBudgetSummaryProvider);
      expect(summary.totalLimit, 50000);
    });

    test('Updating a daily budget modifies its name and limit', () async {
      await container.read(budgetsProvider.notifier).createBudget(
            name: 'Makan Siang',
            dailyLimit: 40000,
          );

      final budgetId = (await container.read(budgetsProvider.future)).first.id;
      await container.read(budgetsProvider.notifier).updateBudget(
            id: budgetId,
            name: 'Makan Siang & Malam',
            dailyLimit: 80000,
          );

      final updated = (await container.read(budgetsProvider.future)).first;
      expect(updated.name, 'Makan Siang & Malam');
      expect(updated.dailyLimit, 80000);
    });

    test('Creating a weekly budget stores period and date range correctly', () async {
      await container.read(budgetsProvider.notifier).createBudget(
            name: 'Belanja Mingguan',
            dailyLimit: 350000,
            period: BudgetPeriod.weekly,
            startDate: '2026-10-12',
            endDate: '2026-10-18',
          );

      final budgets = await container.read(budgetsProvider.future);
      final weeklyBudget = budgets.firstWhere((b) => b.name == 'Belanja Mingguan');
      expect(weeklyBudget.period, BudgetPeriod.weekly);
      expect(weeklyBudget.isWeekly, true);
      expect(weeklyBudget.isDaily, false);
      expect(weeklyBudget.isMonthly, false);
      expect(weeklyBudget.startDate, '2026-10-12');
      expect(weeklyBudget.endDate, '2026-10-18');
      expect(weeklyBudget.dailyLimit, 350000);
      expect(weeklyBudget.limit, 350000);
    });

    test('Creating a monthly budget stores period and date range correctly', () async {
      await container.read(budgetsProvider.notifier).createBudget(
            name: 'Biaya Hidup Bulanan',
            dailyLimit: 2500000,
            period: BudgetPeriod.monthly,
            startDate: '2026-10-01',
            endDate: '2026-10-31',
          );

      final budgets = await container.read(budgetsProvider.future);
      final monthlyBudget = budgets.firstWhere((b) => b.name == 'Biaya Hidup Bulanan');
      expect(monthlyBudget.period, BudgetPeriod.monthly);
      expect(monthlyBudget.isMonthly, true);
      expect(monthlyBudget.isWeekly, false);
      expect(monthlyBudget.isDaily, false);
      expect(monthlyBudget.startDate, '2026-10-01');
      expect(monthlyBudget.endDate, '2026-10-31');
      expect(monthlyBudget.dailyLimit, 2500000);
    });

    test('Updating a budget period changes its period and dates', () async {
      await container.read(budgetsProvider.notifier).createBudget(
            name: 'Kopi',
            dailyLimit: 20000,
            period: BudgetPeriod.daily,
            startDate: '2026-10-12',
          );

      final budgetId = (await container.read(budgetsProvider.future)).first.id;
      await container.read(budgetsProvider.notifier).updateBudget(
            id: budgetId,
            name: 'Kopi Mingguan',
            dailyLimit: 100000,
            period: BudgetPeriod.weekly,
            startDate: '2026-10-12',
            endDate: '2026-10-18',
          );

      final updated = (await container.read(budgetsProvider.future)).first;
      expect(updated.name, 'Kopi Mingguan');
      expect(updated.period, BudgetPeriod.weekly);
      expect(updated.dailyLimit, 100000);
      expect(updated.endDate, '2026-10-18');
    });
  });
}
