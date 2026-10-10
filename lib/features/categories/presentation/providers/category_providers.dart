import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/shared/models/category_model.dart';
import 'package:tally/shared/repositories/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final repo = ref.read(categoryRepositoryProvider);
  return repo.getAll(includeArchived: false);
});

final expenseCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final all = ref.watch(categoriesProvider).valueOrNull ?? [];
  return all.where((c) => c.type == CategoryType.expense).toList();
});

final incomeCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final all = ref.watch(categoriesProvider).valueOrNull ?? [];
  return all.where((c) => c.type == CategoryType.income).toList();
});
