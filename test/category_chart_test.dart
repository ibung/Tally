import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/features/categories/presentation/categories_screen.dart';
import 'package:tally/features/categories/presentation/helpers/chart_palette.dart';
import 'package:tally/features/categories/presentation/providers/category_providers.dart';
import 'package:tally/features/categories/presentation/widgets/category_bar_chart.dart';
import 'package:tally/features/categories/presentation/widgets/category_pie_chart.dart';
import 'package:tally/shared/models/category_model.dart';
import 'package:tally/shared/repositories/category_repository.dart';

class FakeCategoryRepository implements CategoryRepository {
  final List<CategoryModel> _categories = [];
  final List<CategoryChartItem> _expenseChartItems = [];
  final List<CategoryChartItem> _incomeChartItems = [];

  void addCategory(CategoryModel c) => _categories.add(c);
  void setExpenseChartItems(List<CategoryChartItem> items) => _expenseChartItems
    ..clear()
    ..addAll(items);
  void setIncomeChartItems(List<CategoryChartItem> items) => _incomeChartItems
    ..clear()
    ..addAll(items);

  @override
  Future<List<CategoryModel>> getAll({
    CategoryType? type,
    bool includeArchived = false,
  }) async {
    return _categories.where((c) {
      if (!includeArchived && c.isArchived) return false;
      if (type != null && c.type != type) return false;
      return true;
    }).toList();
  }

  @override
  Future<CategoryModel?> getById(String id) async {
    return _categories.where((c) => c.id == id).firstOrNull;
  }

  @override
  Future<int> insert(CategoryModel category) async {
    _categories.add(category);
    return 1;
  }

  @override
  Future<int> update(CategoryModel category) async {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx != -1) {
      _categories[idx] = category;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> archive(String id, {bool archived = true}) async {
    final idx = _categories.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _categories[idx] = _categories[idx].copyWith(isArchived: archived);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> delete(String id) async {
    _categories.removeWhere((c) => c.id == id);
    return 1;
  }

  @override
  Future<List<CategoryChartItem>> getCategoryBreakdown({
    required CategoryType type,
    String? startDate,
    String? endDate,
  }) async {
    if (type == CategoryType.expense) {
      return _expenseChartItems;
    } else {
      return _incomeChartItems;
    }
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('CategoryChartItem & ChartPalette Unit Tests', () {
    test('CategoryChartItem holds data correctly', () {
      const item = CategoryChartItem(
        categoryId: 'cat-1',
        categoryName: 'Makanan & Minuman',
        categoryIcon: 'food',
        categoryColor: '#0A0A0A',
        type: CategoryType.expense,
        totalAmount: 150000,
        transactionCount: 3,
        percentage: 0.6,
      );

      expect(item.categoryId, 'cat-1');
      expect(item.categoryName, 'Makanan & Minuman');
      expect(item.totalAmount, 150000);
      expect(item.percentage, 0.6);
      expect(item.transactionCount, 3);
      expect(item.type, CategoryType.expense);
    });

    test('ChartPalette provides distinct colors for light and dark modes', () {
      final colorLight0 = ChartPalette.getColor(0, false);
      final colorDark0 = ChartPalette.getColor(0, true);
      final colorLight1 = ChartPalette.getColor(1, false);

      expect(colorLight0, isA<Color>());
      expect(colorDark0, isA<Color>());
      expect(colorLight0, isNot(equals(colorLight1)));
    });
  });

  group('Category Charts Widget Tests', () {
    final sampleExpenseItems = [
      const CategoryChartItem(
        categoryId: 'cat-1',
        categoryName: 'Makanan & Minuman',
        categoryIcon: 'food',
        categoryColor: '#0A0A0A',
        type: CategoryType.expense,
        totalAmount: 300000,
        transactionCount: 4,
        percentage: 0.6,
      ),
      const CategoryChartItem(
        categoryId: 'cat-2',
        categoryName: 'Transportasi',
        categoryIcon: 'transport',
        categoryColor: '#0A0A0A',
        type: CategoryType.expense,
        totalAmount: 200000,
        transactionCount: 2,
        percentage: 0.4,
      ),
    ];

    testWidgets('CategoryPieChart renders donut breakdown and percentages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryPieChart(
                items: sampleExpenseItems,
                animationProgress: 1.0,
                type: CategoryType.expense,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Pengeluaran'), findsOneWidget);
      expect(find.text('Rp 500.000'), findsOneWidget);
      expect(find.text('Makanan & Minuman'), findsOneWidget);
      expect(find.text('Transportasi'), findsOneWidget);
      expect(find.text('60.0%'), findsOneWidget);
      expect(find.text('40.0%'), findsOneWidget);
    });

    testWidgets('CategoryBarChart renders ranking and bar labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryBarChart(
                items: sampleExpenseItems,
                animationProgress: 1.0,
                type: CategoryType.expense,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Pengeluaran'), findsOneWidget);
      expect(find.text('Rp 500.000'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('Makanan & Minuman'), findsWidgets);
      expect(find.text('Transportasi'), findsOneWidget);
      expect(find.text('Rp 300.000'), findsOneWidget);
      expect(find.text('Rp 200.000'), findsOneWidget);
    });

    testWidgets('CategoriesScreen switches between Grafik and Kelola Kategori tabs', (tester) async {
      final fakeRepo = FakeCategoryRepository();
      fakeRepo.setExpenseChartItems(sampleExpenseItems);
      fakeRepo.addCategory(
        CategoryModel(
          id: 'cat-1',
          name: 'Makanan & Minuman',
          type: CategoryType.expense,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: CategoriesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts in Grafik Analisis tab by default
      expect(find.text('Grafik Analisis'), findsOneWidget);
      expect(find.text('Kelola Kategori'), findsWidgets);
      expect(find.text('Pengeluaran'), findsWidgets);
      expect(find.text('Pemasukan'), findsOneWidget);

      // Tap 'Kelola Kategori' tab
      await tester.tap(find.text('Kelola Kategori').first);
      await tester.pumpAndSettle();

      // Now shows list management items
      expect(find.text('Kategori Aktif'), findsOneWidget);
      expect(find.text('Tambah'), findsOneWidget);

      // Tap back to 'Grafik Analisis' tab
      await tester.tap(find.text('Grafik Analisis'));
      await tester.pumpAndSettle();

      // Verify chart style toggle (switch to Bar Chart)
      final barButton = find.byTooltip('Bar Chart');
      if (barButton.evaluate().isNotEmpty) {
        await tester.tap(barButton);
        await tester.pumpAndSettle();
        expect(find.text('#1'), findsOneWidget);
      }
    });
  });
}
