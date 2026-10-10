import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/budgets/presentation/providers/budget_providers.dart';
import 'package:tally/shared/models/budget_model.dart';

class BudgetFormSheet extends ConsumerStatefulWidget {
  final DailyBudgetModel? initialBudget;

  const BudgetFormSheet({super.key, this.initialBudget});

  static Future<void> show(BuildContext context, {DailyBudgetModel? budget}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BudgetFormSheet(initialBudget: budget),
    );
  }

  @override
  ConsumerState<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<BudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _limitController;
  bool _isLoading = false;

  static const _suggestions = [
    'Makan',
    'Kopi & Jajan',
    'Transportasi',
    'Bensin',
    'Belanja Harian',
  ];

  @override
  void initState() {
    super.initState();
    final budget = widget.initialBudget;
    _nameController = TextEditingController(text: budget?.name ?? '');

    final initialLimit = budget?.dailyLimit ?? 0;
    _limitController = TextEditingController(
      text: initialLimit > 0 ? CurrencyFormatter.format(initialLimit) : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  void _onLimitChanged(String value) {
    final parsed = CurrencyFormatter.parseInt(value);
    final formatted = parsed > 0 ? CurrencyFormatter.format(parsed) : '';
    if (formatted != value) {
      _limitController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final name = _nameController.text.trim();
    final dailyLimit = CurrencyFormatter.parseInt(_limitController.text);

    try {
      if (widget.initialBudget != null) {
        await ref.read(budgetsProvider.notifier).updateBudget(
              id: widget.initialBudget!.id,
              name: name,
              dailyLimit: dailyLimit,
            );
      } else {
        await ref.read(budgetsProvider.notifier).createBudget(
              name: name,
              dailyLimit: dailyLimit,
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
    final isEdit = widget.initialBudget != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: bottomInset + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                    color: AppTheme.grey200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                isEdit ? 'Edit Kuota Harian' : 'Tambah Kuota Harian',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),

              // Nama Kuota
              const Text(
                'Nama Kuota',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Makan Siang, Kopi, Jajan',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama kuota tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Saran Nama Kuota
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _suggestions.map((suggestion) {
                  return InkWell(
                    onTap: () => setState(() => _nameController.text = suggestion),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.grey100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.grey200),
                      ),
                      child: Text(
                        suggestion,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.grey800,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Batas Harian (Rp)
              const Text(
                'Batas Maksimal per Hari (Rp)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onLimitChanged,
                decoration: const InputDecoration(
                  hintText: 'Rp 50.000',
                ),
                validator: (val) {
                  final amount = CurrencyFormatter.parseInt(val ?? '');
                  if (amount <= 0) {
                    return 'Batas harian harus lebih besar dari 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Info PRD: Reset tiap hari tanpa rollover
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.grey200),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppTheme.grey800,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kuota ini dihitung per hari tanpa rollover. Penggunaan akan otomatis direset ke 0 pada hari berikutnya.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.grey600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Simpan
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.white,
                        ),
                      )
                    : Text(
                        isEdit ? 'Simpan Perubahan' : 'Buat Kuota',
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
