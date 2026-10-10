import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/budgets/presentation/providers/budget_providers.dart';
import 'package:tally/features/categories/presentation/providers/category_providers.dart';
import 'package:tally/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:tally/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:tally/shared/models/budget_model.dart';
import 'package:tally/shared/models/transaction_model.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  final TransactionModel? initialTransaction;
  final DateTime? initialDate;

  const TransactionFormSheet({
    super.key,
    this.initialTransaction,
    this.initialDate,
  });

  static Future<void> show(
    BuildContext context, {
    TransactionModel? transaction,
    DateTime? date,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionFormSheet(
        initialTransaction: transaction,
        initialDate: date,
      ),
    );
  }

  @override
  ConsumerState<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TransactionType _selectedType;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _selectedDateTime;

  String? _selectedWalletId;
  String? _selectedSourceWalletId;
  String? _selectedDestinationWalletId;
  String? _selectedCategoryId;
  String? _selectedBudgetId;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;

    _selectedType = tx?.type ?? TransactionType.expense;
    _selectedDateTime = tx?.occurredAt ?? widget.initialDate ?? DateTime.now();

    final initialAmount = tx?.amount ?? 0;
    _amountController = TextEditingController(
      text: initialAmount > 0 ? CurrencyFormatter.format(initialAmount) : '',
    );
    _noteController = TextEditingController(text: tx?.note ?? '');

    _selectedWalletId = tx?.walletId;
    _selectedSourceWalletId = tx?.sourceWalletId;
    _selectedDestinationWalletId = tx?.destinationWalletId;
    _selectedCategoryId = tx?.categoryId;
    _selectedBudgetId = tx?.budgetId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    final parsed = CurrencyFormatter.parseInt(value);
    final formatted = parsed > 0 ? CurrencyFormatter.format(parsed) : '';
    if (formatted != value) {
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {}); // Re-render for over-budget warning check
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.black,
              onPrimary: AppTheme.white,
              onSurface: AppTheme.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.black,
              onPrimary: AppTheme.white,
              onSurface: AppTheme.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = CurrencyFormatter.parseInt(_amountController.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal transaksi harus lebih besar dari Rp 0')),
      );
      return;
    }

    if (_selectedType == TransactionType.transfer) {
      if (_selectedSourceWalletId == null || _selectedDestinationWalletId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih dompet asal dan tujuan transfer')),
        );
        return;
      }
      if (_selectedSourceWalletId == _selectedDestinationWalletId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dompet asal dan dompet tujuan tidak boleh sama')),
        );
        return;
      }
    } else {
      if (_selectedWalletId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih dompet yang digunakan')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (widget.initialTransaction != null) {
        await ref.read(transactionsProvider.notifier).updateTransaction(
              id: widget.initialTransaction!.id,
              type: _selectedType,
              amount: amount,
              walletId: _selectedType != TransactionType.transfer ? _selectedWalletId : null,
              sourceWalletId:
                  _selectedType == TransactionType.transfer ? _selectedSourceWalletId : null,
              destinationWalletId:
                  _selectedType == TransactionType.transfer ? _selectedDestinationWalletId : null,
              categoryId:
                  _selectedType != TransactionType.transfer ? _selectedCategoryId : null,
              budgetId:
                  _selectedType == TransactionType.expense ? _selectedBudgetId : null,
              occurredAt: _selectedDateTime,
              note: _noteController.text,
            );
      } else {
        await ref.read(transactionsProvider.notifier).createTransaction(
              type: _selectedType,
              amount: amount,
              walletId: _selectedType != TransactionType.transfer ? _selectedWalletId : null,
              sourceWalletId:
                  _selectedType == TransactionType.transfer ? _selectedSourceWalletId : null,
              destinationWalletId:
                  _selectedType == TransactionType.transfer ? _selectedDestinationWalletId : null,
              categoryId:
                  _selectedType != TransactionType.transfer ? _selectedCategoryId : null,
              budgetId:
                  _selectedType == TransactionType.expense ? _selectedBudgetId : null,
              occurredAt: _selectedDateTime,
              note: _noteController.text,
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
    final isEdit = widget.initialTransaction != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final wallets = ref.watch(walletsProvider).valueOrNull?.where((w) => !w.isArchived).toList() ?? [];
    final categories = _selectedType == TransactionType.income
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(expenseCategoriesProvider);
    final budgets = ref.watch(budgetsProvider).valueOrNull?.where((b) => b.isActive).toList() ?? [];

    // Auto-select first wallet if only one wallet exists and none selected
    if (wallets.isNotEmpty && _selectedWalletId == null && _selectedType != TransactionType.transfer) {
      _selectedWalletId = wallets.first.id;
    }
    if (wallets.length >= 2 && _selectedType == TransactionType.transfer) {
      _selectedSourceWalletId ??= wallets[0].id;
      _selectedDestinationWalletId ??= wallets[1].id;
    }

    // Over-budget check for Expense (PRD Bab 7)
    final inputAmount = CurrencyFormatter.parseInt(_amountController.text);
    DailyBudgetModel? selectedBudget;
    if (_selectedType == TransactionType.expense && _selectedBudgetId != null) {
      try {
        selectedBudget = budgets.firstWhere((b) => b.id == _selectedBudgetId);
      } catch (_) {}
    }
    final isOverBudgetWarning = selectedBudget != null && inputAmount > selectedBudget.remaining;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
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
              // Handle indicator
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
                isEdit ? 'Edit Transaksi' : 'Catat Transaksi',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 18),

              // Type Switcher: Pengeluaran | Pemasukan | Transfer
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _TypeTab(
                      label: 'Pengeluaran',
                      isSelected: _selectedType == TransactionType.expense,
                      onTap: () => setState(() {
                        _selectedType = TransactionType.expense;
                        _selectedCategoryId = null;
                      }),
                    ),
                    _TypeTab(
                      label: 'Pemasukan',
                      isSelected: _selectedType == TransactionType.income,
                      onTap: () => setState(() {
                        _selectedType = TransactionType.income;
                        _selectedBudgetId = null;
                        _selectedCategoryId = null;
                      }),
                    ),
                    _TypeTab(
                      label: 'Transfer',
                      isSelected: _selectedType == TransactionType.transfer,
                      onTap: () => setState(() {
                        _selectedType = TransactionType.transfer;
                        _selectedBudgetId = null;
                        _selectedCategoryId = null;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Nominal Input (Besar & Prominen)
              const Text(
                'Nominal (Rp)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onAmountChanged,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.black,
                ),
                decoration: const InputDecoration(
                  hintText: 'Rp 0',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),

              // Over-Budget Warning Notice (Prinsip PRD: tidak menghakimi)
              if (isOverBudgetWarning) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.black, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 20, color: AppTheme.black),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nominal ini melebihi sisa kuota "${selectedBudget.name}" (${CurrencyFormatter.format(selectedBudget.remaining)}). Transaksi tetap dapat disimpan.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.black,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Wallet Selector (Income / Expense)
              if (_selectedType != TransactionType.transfer) ...[
                const Text(
                  'Dompet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.black,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedWalletId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: wallets.map((w) {
                    return DropdownMenuItem(
                      value: w.id,
                      child: Text('${w.name} (${CurrencyFormatter.format(w.currentBalance)})'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedWalletId = val),
                ),
                const SizedBox(height: 20),
              ],

              // Transfer: Source & Destination Wallets
              if (_selectedType == TransactionType.transfer) ...[
                const Text(
                  'Dari Dompet (Sumber)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.black),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSourceWalletId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: wallets.map((w) {
                    return DropdownMenuItem(value: w.id, child: Text(w.name));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedSourceWalletId = val),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Ke Dompet (Tujuan)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.black),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDestinationWalletId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: wallets.map((w) {
                    return DropdownMenuItem(value: w.id, child: Text(w.name));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedDestinationWalletId = val),
                ),
                const SizedBox(height: 20),
              ],

              // Kuota Harian (Khusus Pengeluaran, PRD Bab 7)
              if (_selectedType == TransactionType.expense && budgets.isNotEmpty) ...[
                const Text(
                  'Kuota Harian (Opsional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.black,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedBudgetId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tanpa Kuota'),
                    ),
                    ...budgets.map((b) {
                      return DropdownMenuItem(
                        value: b.id,
                        child: Text('${b.name} (Sisa: ${CurrencyFormatter.format(b.remaining)})'),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _selectedBudgetId = val),
                ),
                const SizedBox(height: 20),
              ],

              // Kategori (Khusus Income / Expense)
              if (_selectedType != TransactionType.transfer && categories.isNotEmpty) ...[
                const Text(
                  'Kategori (Opsional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.black,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tanpa Kategori'),
                    ),
                    ...categories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
                ),
                const SizedBox(height: 20),
              ],

              // Tanggal & Waktu
              const Text(
                'Tanggal & Waktu Transaksi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.grey200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.black),
                      const SizedBox(width: 12),
                      Text(
                        DateFormatter.formatDateTime(_selectedDateTime),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.black,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.grey600),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Catatan (Opsional)
              const Text(
                'Catatan (Opsional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Makan siang nasi padang',
                ),
              ),
              const SizedBox(height: 28),

              // Tombol Simpan Transaksi
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
                        isEdit ? 'Simpan Perubahan' : 'Catat Transaksi',
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
            color: isSelected ? AppTheme.black : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.white : AppTheme.grey800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
