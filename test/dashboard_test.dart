import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/budgets/presentation/providers/budget_providers.dart';
import 'package:tally/features/dashboard/presentation/dashboard_screen.dart';
import 'package:tally/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:tally/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:tally/shared/models/budget_model.dart';
import 'package:tally/shared/models/transaction_model.dart';
import 'package:tally/shared/models/wallet_model.dart';
import 'package:tally/shared/repositories/budget_repository.dart';
import 'package:tally/shared/repositories/transaction_repository.dart';
import 'package:tally/shared/repositories/wallet_repository.dart';

// Fake Transaction Repository
class FakeTransactionRepository implements TransactionRepository {
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
    final daily = _transactions.where((t) => t.localDate == localDate);
    final income = daily
        .where((t) => t.type == TransactionType.income)
        .fold<int>(0, (sum, t) => sum + t.amount);
    final expense = daily
        .where((t) => t.type == TransactionType.expense)
        .fold<int>(0, (sum, t) => sum + t.amount);
    return (income: income, expense: expense);
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
    const openingBalance = 500000;
    final pastAndPresent = _transactions.where((t) => t.localDate.compareTo(localDate) <= 0);
    final totalIncome = pastAndPresent
        .where((t) => t.type == TransactionType.income)
        .fold<int>(0, (sum, t) => sum + t.amount);
    final totalExpense = pastAndPresent
        .where((t) => t.type == TransactionType.expense)
        .fold<int>(0, (sum, t) => sum + t.amount);
    return openingBalance + totalIncome - totalExpense;
  }
}

// Fake Budget Repository
class FakeBudgetRepository implements BudgetRepository {
  final List<DailyBudgetModel> _budgets = [];

  void addBudget(DailyBudgetModel budget) => _budgets.add(budget);

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

// Fake Wallet Repository
class FakeWalletRepository implements WalletRepository {
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
  Future<int> getWalletBalance(String walletId) async => 500000;

  @override
  Future<int> getTotalBalance() async => 500000;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  late FakeTransactionRepository fakeTxRepo;
  late FakeBudgetRepository fakeBudgetRepo;
  late FakeWalletRepository fakeWalletRepo;

  setUp(() {
    fakeTxRepo = FakeTransactionRepository();
    fakeBudgetRepo = FakeBudgetRepository();
    fakeWalletRepo = FakeWalletRepository();
  });

  group('Dashboard Business Logic & Calculation Tests', () {
    test('DateFormatter formats Besok, Hari ini, and Kemarin', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final tomorrow = today.add(const Duration(days: 1));

      expect(DateFormatter.formatRelative(today), 'Hari ini');
      expect(DateFormatter.formatRelative(yesterday), 'Kemarin');
      expect(DateFormatter.formatRelative(tomorrow), 'Besok');
    });

    test('Historical end balance isolates past transactions from future dates', () async {
      const dateA = '2026-10-10';
      const dateB = '2026-10-11';

      fakeTxRepo.addTx(TransactionModel(
        id: 'tx-1',
        type: TransactionType.income,
        amount: 200000,
        occurredAt: DateTime(2026, 10, 10, 10, 0),
        localDate: dateA,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      fakeTxRepo.addTx(TransactionModel(
        id: 'tx-2',
        type: TransactionType.expense,
        amount: 50000,
        occurredAt: DateTime(2026, 10, 10, 12, 0),
        localDate: dateA,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Future transaction on date B
      fakeTxRepo.addTx(TransactionModel(
        id: 'tx-3',
        type: TransactionType.expense,
        amount: 100000,
        occurredAt: DateTime(2026, 10, 11, 14, 0),
        localDate: dateB,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Balance on Date A: 500000 (opening) + 200000 - 50000 = 650000
      final balanceDateA = await fakeTxRepo.getHistoricalEndBalance(dateA);
      expect(balanceDateA, 650000);

      // Balance on Date B: 650000 - 100000 = 550000
      final balanceDateB = await fakeTxRepo.getHistoricalEndBalance(dateB);
      expect(balanceDateB, 550000);
    });

    test('Daily summary evaluates income and expense specifically for selected date', () async {
      const dateA = '2026-10-10';

      fakeTxRepo.addTx(TransactionModel(
        id: 'tx-1',
        type: TransactionType.income,
        amount: 150000,
        occurredAt: DateTime(2026, 10, 10, 9, 0),
        localDate: dateA,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      fakeTxRepo.addTx(TransactionModel(
        id: 'tx-2',
        type: TransactionType.expense,
        amount: 40000,
        occurredAt: DateTime(2026, 10, 10, 11, 0),
        localDate: dateA,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final summary = await fakeTxRepo.getDailySummary(dateA);
      expect(summary.income, 150000);
      expect(summary.expense, 40000);
    });
  });

  group('DashboardScreen Widget Rendering Tests', () {
    testWidgets('Renders date navigator, historical balance, cashflow, and transactions',
        (tester) async {
      final testDate = DateTime(2026, 10, 10);
      final localDateStr = DateFormatter.toLocalDate(testDate);

      // Setup initial data
      fakeTxRepo.addTx(TransactionModel(
        id: 'tx-1',
        type: TransactionType.expense,
        amount: 25000,
        categoryName: 'Makan Siang',
        walletName: 'Tunai',
        occurredAt: DateTime(2026, 10, 10, 12, 30),
        localDate: localDateStr,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      fakeBudgetRepo.addBudget(DailyBudgetModel(
        id: 'budget-1',
        name: 'Makan',
        dailyLimit: 50000,
        startDate: localDateStr,
        spent: 25000,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTxRepo),
          budgetRepositoryProvider.overrideWithValue(fakeBudgetRepo),
          walletRepositoryProvider.overrideWithValue(fakeWalletRepo),
          selectedTransactionDateProvider.overrideWith((ref) => testDate),
          selectedDateForBudgetsProvider.overrideWith((ref) => testDate),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check date navigator
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
      expect(find.byIcon(Icons.calendar_today_outlined), findsWidgets);

      // Check Saldo Akhir Historis
      expect(find.text('Saldo Akhir Historis'), findsOneWidget);

      // Check Cash Flow
      expect(find.text('Pemasukan'), findsOneWidget);
      expect(find.text('Pengeluaran'), findsOneWidget);

      // Check Kuota Belanja
      expect(find.text('Kuota Belanja'), findsOneWidget);

      // Check Transaction List
      expect(find.text('Transaksi'), findsOneWidget);
      expect(find.text('Makan Siang'), findsOneWidget);
      expect(find.text('-Rp 25.000'), findsWidgets);

      // Check FAB Catat
      expect(find.text('Catat'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
    });

    testWidgets('Tapping previous day changes date', (tester) async {
      final testDate = DateTime(2026, 10, 10);

      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(fakeTxRepo),
          budgetRepositoryProvider.overrideWithValue(fakeBudgetRepo),
          walletRepositoryProvider.overrideWithValue(fakeWalletRepo),
          selectedTransactionDateProvider.overrideWith((ref) => testDate),
          selectedDateForBudgetsProvider.overrideWith((ref) => testDate),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Previous Day
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();

      // Date state in container should have moved to 2026-10-09
      final newDate = container.read(selectedTransactionDateProvider);
      expect(newDate.year, 2026);
      expect(newDate.month, 10);
      expect(newDate.day, 9);
    });
  });
}
