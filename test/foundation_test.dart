import 'package:flutter_test/flutter_test.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/shared/models/wallet_model.dart';
import 'package:tally/shared/models/category_model.dart';
import 'package:tally/shared/models/budget_model.dart';
import 'package:tally/shared/models/transaction_model.dart';

void main() {
  group('Formatters Unit Tests', () {
    test('CurrencyFormatter formats integer Rupiah properly', () {
      expect(CurrencyFormatter.format(25000), 'Rp 25.000');
      expect(CurrencyFormatter.format(0), 'Rp 0');
      expect(CurrencyFormatter.format(1500000), 'Rp 1.500.000');
    });

    test('CurrencyFormatter parses input string to Rupiah integer', () {
      expect(CurrencyFormatter.parseInt('Rp 25.000'), 25000);
      expect(CurrencyFormatter.parseInt('1.500.000'), 1500000);
      expect(CurrencyFormatter.parseInt(''), 0);
    });

    test('DateFormatter formats and parses local_date (YYYY-MM-DD)', () {
      final date = DateTime(2026, 10, 10);
      final localDateStr = DateFormatter.toLocalDate(date);
      expect(localDateStr, '2026-10-10');

      final parsed = DateFormatter.parseLocalDate(localDateStr);
      expect(parsed.year, 2026);
      expect(parsed.month, 10);
      expect(parsed.day, 10);
    });
  });

  group('PRD Models Logic & Serialization Tests', () {
    test('DailyBudgetModel calculates remaining and over-budget correctly', () {
      final now = DateTime.now();
      final budget = DailyBudgetModel(
        id: 'budget-1',
        name: 'Makan',
        dailyLimit: 50000,
        startDate: '2026-10-10',
        createdAt: now,
        updatedAt: now,
        spent: 30000,
      );

      expect(budget.remaining, 20000);
      expect(budget.isOverBudget, false);
      expect(budget.percentage, 0.6);

      final overBudget = budget.copyWith(spent: 60000);
      expect(overBudget.remaining, -10000);
      expect(overBudget.isOverBudget, true);
    });

    test('WalletModel correctly serializes and deserializes', () {
      final now = DateTime.now();
      final wallet = WalletModel(
        id: 'wallet-1',
        name: 'Dompet Utama',
        type: 'cash',
        openingBalance: 100000,
        currentBalance: 150000,
        color: '#0A0A0A',
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

      final map = wallet.toMap();
      expect(map['id'], 'wallet-1');
      expect(map['opening_balance'], 100000);
      expect(map['is_archived'], 0);

      final fromMap = WalletModel.fromMap(map, calculatedBalance: 150000);
      expect(fromMap.id, wallet.id);
      expect(fromMap.openingBalance, 100000);
      expect(fromMap.currentBalance, 150000);
    });

    test('TransactionModel correctly serializes and deserializes', () {
      final now = DateTime.now();
      final tx = TransactionModel(
        id: 'tx-1',
        type: TransactionType.expense,
        amount: 25000,
        walletId: 'wallet-1',
        budgetId: 'budget-1',
        occurredAt: now,
        localDate: '2026-10-10',
        note: 'Makan Siang',
        createdAt: now,
        updatedAt: now,
      );

      final map = tx.toMap();
      expect(map['id'], 'tx-1');
      expect(map['amount'], 25000);
      expect(map['type'], 'expense');
      expect(map['local_date'], '2026-10-10');
      expect(map['budget_id'], 'budget-1');

      final fromMap = TransactionModel.fromMap(map);
      expect(fromMap.id, tx.id);
      expect(fromMap.amount, 25000);
      expect(fromMap.type, TransactionType.expense);
    });

    test('CategoryModel correctly identifies income and expense', () {
      final now = DateTime.now();
      final cat = CategoryModel(
        id: 'cat-1',
        name: 'Makanan',
        type: CategoryType.expense,
        createdAt: now,
        updatedAt: now,
      );

      final map = cat.toMap();
      expect(map['type'], 'expense');
      expect(CategoryModel.fromMap(map).type, CategoryType.expense);
    });
  });
}
