import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/features/categories/presentation/helpers/category_icon_helper.dart';
import 'package:tally/features/categories/presentation/providers/category_providers.dart';
import 'package:tally/features/categories/presentation/widgets/category_form_sheet.dart';
import 'package:tally/shared/models/category_model.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryType? _selectedTypeFilter; // null = Semua
  bool _showArchived = false;

  void _showCategoryOptions(BuildContext context, CategoryModel category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.grey100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CategoryIconHelper.getIcon(category.icon),
                      color: AppTheme.black,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.black,
                          ),
                        ),
                        Text(
                          category.type == CategoryType.expense
                              ? 'Kategori Pengeluaran'
                              : 'Kategori Pemasukan',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.grey600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.grey200, height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppTheme.black),
              title: const Text('Edit Kategori'),
              onTap: () {
                Navigator.pop(ctx);
                CategoryFormSheet.show(context, category: category);
              },
            ),
            ListTile(
              leading: Icon(
                category.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                color: AppTheme.black,
              ),
              title: Text(
                category.isArchived ? 'Pulihkan Kategori' : 'Arsipkan Kategori',
              ),
              subtitle: Text(
                category.isArchived
                    ? 'Tampilkan kembali di pilihan transaksi'
                    : 'Sembunyikan dari pilihan saat mencatat transaksi',
                style: const TextStyle(fontSize: 11, color: AppTheme.grey600),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await ref
                    .read(categoriesProvider.notifier)
                    .toggleArchive(category.id, !category.isArchived);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        category.isArchived
                            ? 'Kategori "${category.name}" dipulihkan'
                            : 'Kategori "${category.name}" diarsipkan',
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.black),
              title: const Text(
                'Hapus Kategori',
                style: TextStyle(color: AppTheme.black),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteCategory(context, category);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Kategori?',
          style: TextStyle(color: AppTheme.black, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Kategori "${category.name}" akan dihapus permanen. Transaksi lama dengan kategori ini tidak akan terhapus.',
          style: const TextStyle(color: AppTheme.grey800, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.grey600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.black,
              foregroundColor: AppTheme.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(categoriesProvider.notifier).deleteCategory(category.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Kategori "${category.name}" telah dihapus')),
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: RefreshIndicator(
        color: AppTheme.black,
        backgroundColor: AppTheme.white,
        onRefresh: () => ref.read(categoriesProvider.notifier).refresh(),
        child: categoriesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.black),
          ),
          error: (err, _) => Center(
            child: Text('Terjadi kesalahan: $err'),
          ),
          data: (allCategories) {
            final activeList = allCategories.where((c) => !c.isArchived).toList();
            final archivedList = allCategories.where((c) => c.isArchived).toList();

            final expenseCount = activeList.where((c) => c.type == CategoryType.expense).length;
            final incomeCount = activeList.where((c) => c.type == CategoryType.income).length;

            final baseList = _showArchived ? archivedList : activeList;
            final displayedCategories = _selectedTypeFilter == null
                ? baseList
                : baseList.where((c) => c.type == _selectedTypeFilter).toList();

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card Ringkasan Kategori
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.black, width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x08000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.grid_view_rounded,
                                    size: 18,
                                    color: AppTheme.grey600,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Kelola Kategori',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.grey600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${activeList.length}',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.black,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Kategori Aktif',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.grey600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _MiniStatBadge(
                                    label: '$expenseCount Pengeluaran',
                                    icon: Icons.arrow_upward_rounded,
                                  ),
                                  const SizedBox(width: 8),
                                  _MiniStatBadge(
                                    label: '$incomeCount Pemasukan',
                                    icon: Icons.arrow_downward_rounded,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Filter Tabs & Tombol Tambah
                        Row(
                          children: [
                            // Filter Status (Aktif / Diarsipkan)
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppTheme.grey100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  _FilterChip(
                                    label: 'Aktif',
                                    selected: !_showArchived,
                                    onTap: () => setState(() => _showArchived = false),
                                  ),
                                  _FilterChip(
                                    label: 'Diarsipkan',
                                    selected: _showArchived,
                                    onTap: () => setState(() => _showArchived = true),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),

                            // Tombol Tambah Kategori
                            InkWell(
                              onTap: () => CategoryFormSheet.show(
                                context,
                                defaultType: _selectedTypeFilter ?? CategoryType.expense,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.black,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.add_rounded, size: 16, color: AppTheme.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tambah',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Sub Filter: Semua | Pengeluaran | Pemasukan
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              _TypeFilterChip(
                                label: 'Semua',
                                selected: _selectedTypeFilter == null,
                                onTap: () => setState(() => _selectedTypeFilter = null),
                              ),
                              const SizedBox(width: 8),
                              _TypeFilterChip(
                                label: 'Pengeluaran',
                                selected: _selectedTypeFilter == CategoryType.expense,
                                onTap: () => setState(() {
                                  _selectedTypeFilter = _selectedTypeFilter == CategoryType.expense
                                      ? null
                                      : CategoryType.expense;
                                }),
                              ),
                              const SizedBox(width: 8),
                              _TypeFilterChip(
                                label: 'Pemasukan',
                                selected: _selectedTypeFilter == CategoryType.income,
                                onTap: () => setState(() {
                                  _selectedTypeFilter = _selectedTypeFilter == CategoryType.income
                                      ? null
                                      : CategoryType.income;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Daftar Kategori
                if (displayedCategories.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: AppTheme.grey100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.category_outlined,
                                size: 30,
                                color: AppTheme.grey600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showArchived
                                  ? 'Tidak ada kategori yang diarsipkan'
                                  : 'Belum ada kategori',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.black,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _showArchived
                                  ? 'Kategori yang diarsipkan akan tampil di sini'
                                  : 'Tambahkan kategori baru untuk mencatat keuangan lebih teratur',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.grey600,
                              ),
                            ),
                            if (!_showArchived) ...[
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                onPressed: () => CategoryFormSheet.show(
                                  context,
                                  defaultType: _selectedTypeFilter ?? CategoryType.expense,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.black,
                                  side: const BorderSide(color: AppTheme.black),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text(
                                  'Tambah Kategori',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final category = displayedCategories[index];
                          final iconData = CategoryIconHelper.getIcon(category.icon);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.grey200),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => _showCategoryOptions(context, category),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      // Ikon Kategori
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppTheme.grey100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          iconData,
                                          size: 22,
                                          color: AppTheme.black,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Nama & Tipe
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              category.name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: category.isArchived
                                                    ? AppTheme.grey600
                                                    : AppTheme.black,
                                                decoration: category.isArchived
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: category.type == CategoryType.expense
                                                        ? AppTheme.grey100
                                                        : AppTheme.grey100,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    category.type == CategoryType.expense
                                                        ? 'Pengeluaran'
                                                        : 'Pemasukan',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppTheme.grey800,
                                                    ),
                                                  ),
                                                ),
                                                if (category.isArchived) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.grey200,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      'Diarsipkan',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w500,
                                                        color: AppTheme.grey600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Action Icon
                                      const Icon(
                                        Icons.more_vert_rounded,
                                        size: 20,
                                        color: AppTheme.grey600,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: displayedCategories.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? AppTheme.black : AppTheme.grey600,
          ),
        ),
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.black : AppTheme.grey100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.black : AppTheme.grey200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? AppTheme.white : AppTheme.grey800,
          ),
        ),
      ),
    );
  }
}

class _MiniStatBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MiniStatBadge({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.black),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.black,
            ),
          ),
        ],
      ),
    );
  }
}
