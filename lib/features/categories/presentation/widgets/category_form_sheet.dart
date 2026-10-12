import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/features/categories/presentation/helpers/category_icon_helper.dart';
import 'package:tally/features/categories/presentation/providers/category_providers.dart';
import 'package:tally/shared/models/category_model.dart';

class CategoryFormSheet extends ConsumerStatefulWidget {
  final CategoryModel? initialCategory;
  final CategoryType? defaultType;

  const CategoryFormSheet({
    super.key,
    this.initialCategory,
    this.defaultType,
  });

  static Future<void> show(
    BuildContext context, {
    CategoryModel? category,
    CategoryType? defaultType,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryFormSheet(
        initialCategory: category,
        defaultType: defaultType,
      ),
    );
  }

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late CategoryType _selectedType;
  late String _selectedIcon;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final cat = widget.initialCategory;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _selectedType = cat?.type ?? widget.defaultType ?? CategoryType.expense;
    _selectedIcon = cat?.icon ?? 'other';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final name = _nameController.text.trim();

    try {
      if (widget.initialCategory != null) {
        await ref.read(categoriesProvider.notifier).updateCategory(
              id: widget.initialCategory!.id,
              name: name,
              type: _selectedType,
              icon: _selectedIcon,
            );
      } else {
        await ref.read(categoriesProvider.notifier).createCategory(
              name: name,
              type: _selectedType,
              icon: _selectedIcon,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialCategory != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    // Batasi tinggi maksimal agar seimbang dan proporsional (~55% layar saat keyboard tertutup)
    final maxAllowedHeight = bottomInset > 0
        ? screenHeight - topPadding - kToolbarHeight - 16
        : screenHeight * 0.55;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxAllowedHeight,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInset + 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                isEdit ? 'Edit Kategori' : 'Tambah Kategori Baru',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Jenis Kategori (Pengeluaran | Pemasukan)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.subtleBg(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _TypeTab(
                      label: 'Pengeluaran',
                      isSelected: _selectedType == CategoryType.expense,
                      onTap: () => setState(() => _selectedType = CategoryType.expense),
                    ),
                    _TypeTab(
                      label: 'Pemasukan',
                      isSelected: _selectedType == CategoryType.income,
                      onTap: () => setState(() => _selectedType = CategoryType.income),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nama Kategori
              Text(
                'Nama Kategori',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Kopi, Langganan, Jajan',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama kategori tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Pilihan Ikon
              Text(
                'Pilih Ikon',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: CategoryIconHelper.availableIcons.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = CategoryIconHelper.availableIcons[index];
                    final isSelected = _selectedIcon == item.key;

                    return InkWell(
                      onTap: () => setState(() => _selectedIcon = item.key),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryButtonBg(context) : AppTheme.subtleBg(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryButtonBg(context) : AppTheme.border(context),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            item.icon,
                            size: 22,
                            color: isSelected ? AppTheme.primaryButtonText(context) : AppTheme.textPrimary(context),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),

              // Tombol Simpan
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryButtonText(context),
                        ),
                      )
                    : Text(
                        isEdit ? 'Simpan Perubahan' : 'Buat Kategori',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryButtonBg(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryButtonText(context) : AppTheme.textSecondary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
