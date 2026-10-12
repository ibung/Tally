import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:tally/shared/models/category_model.dart';
import 'package:tally/shared/repositories/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository();
});

class CategoriesNotifier extends AsyncNotifier<List<CategoryModel>> {
  static const _uuid = Uuid();

  @override
  Future<List<CategoryModel>> build() async {
    return _fetchCategories();
  }

  Future<List<CategoryModel>> _fetchCategories({bool includeArchived = true}) async {
    final repo = ref.read(categoryRepositoryProvider);
    return repo.getAll(includeArchived: includeArchived);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchCategories());
  }

  Future<void> createCategory({
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
  }) async {
    final repo = ref.read(categoryRepositoryProvider);
    final now = DateTime.now();
    final category = CategoryModel(
      id: _uuid.v4(),
      name: name.trim(),
      type: type,
      icon: icon ?? 'other',
      color: color ?? '#0A0A0A',
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    await repo.insert(category);
    await refresh();
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
  }) async {
    final repo = ref.read(categoryRepositoryProvider);
    final current = state.valueOrNull?.firstWhere((c) => c.id == id);
    if (current == null) return;

    final updated = current.copyWith(
      name: name.trim(),
      type: type,
      icon: icon ?? current.icon,
      color: color ?? current.color,
      updatedAt: DateTime.now(),
    );

    await repo.update(updated);
    await refresh();
  }

  Future<void> toggleArchive(String id, bool archived) async {
    final repo = ref.read(categoryRepositoryProvider);
    await repo.archive(id, archived: archived);
    await refresh();
  }

  Future<void> deleteCategory(String id) async {
    final repo = ref.read(categoryRepositoryProvider);
    await repo.delete(id);
    await refresh();
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<CategoryModel>>(
  CategoriesNotifier.new,
);

final activeCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final all = ref.watch(categoriesProvider).valueOrNull ?? [];
  return all.where((c) => !c.isArchived).toList();
});

final expenseCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final active = ref.watch(activeCategoriesProvider);
  return active.where((c) => c.type == CategoryType.expense).toList();
});

final incomeCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final active = ref.watch(activeCategoriesProvider);
  return active.where((c) => c.type == CategoryType.income).toList();
});
