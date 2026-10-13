import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/budgets/presentation/providers/budget_providers.dart';
import 'package:tally/features/categories/presentation/providers/category_providers.dart';
import 'package:tally/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:tally/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:tally/features/categories/presentation/widgets/category_form_sheet.dart';
import 'package:tally/shared/models/budget_model.dart';
import 'package:tally/shared/models/category_model.dart';
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
      builder: (pickerCtx, child) {
        final isDark = AppTheme.isDark(pickerCtx);
        return Theme(
          data: Theme.of(pickerCtx).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppTheme.white,
                    onPrimary: AppTheme.black,
                    surface: AppTheme.darkCard,
                    onSurface: AppTheme.white,
                  )
                : const ColorScheme.light(
                    primary: AppTheme.black,
                    onPrimary: AppTheme.white,
                    surface: AppTheme.white,
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
      builder: (pickerCtx, child) {
        final isDark = AppTheme.isDark(pickerCtx);
        return Theme(
          data: Theme.of(pickerCtx).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppTheme.white,
                    onPrimary: AppTheme.black,
                    surface: AppTheme.darkCard,
                    onSurface: AppTheme.white,
                  )
                : const ColorScheme.light(
                    primary: AppTheme.black,
                    onPrimary: AppTheme.white,
                    surface: AppTheme.white,
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

    final wallets = ref.read(walletsProvider).valueOrNull?.where((w) => !w.isArchived).toList() ?? [];

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
      // Constraint saldo untuk transfer keluar
      final sourceWallet = wallets.where((w) => w.id == _selectedSourceWalletId).firstOrNull;
      if (sourceWallet != null) {
        final isSameSourceEdit = widget.initialTransaction != null &&
            widget.initialTransaction!.sourceWalletId == sourceWallet.id &&
            widget.initialTransaction!.type == TransactionType.transfer;
        final available = sourceWallet.currentBalance +
            (isSameSourceEdit ? widget.initialTransaction!.amount : 0);
        if (amount > available) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Saldo ${sourceWallet.name} tidak mencukupi (Saldo: ${CurrencyFormatter.format(available)})',
              ),
            ),
          );
          return;
        }
      }
    } else {
      if (_selectedWalletId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih dompet yang digunakan')),
        );
        return;
      }
      // Constraint saldo untuk pengeluaran
      if (_selectedType == TransactionType.expense) {
        final wallet = wallets.where((w) => w.id == _selectedWalletId).firstOrNull;
        if (wallet != null) {
          final isSameWalletEdit = widget.initialTransaction != null &&
              widget.initialTransaction!.walletId == wallet.id &&
              widget.initialTransaction!.type == TransactionType.expense;
          final available = wallet.currentBalance +
              (isSameWalletEdit ? widget.initialTransaction!.amount : 0);
          if (amount > available) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Saldo ${wallet.name} tidak mencukupi (Saldo: ${CurrencyFormatter.format(available)})',
                ),
              ),
            );
            return;
          }
        }
      }
    }

    // Constraint Kategori Wajib (Item 2)
    if (_selectedType != TransactionType.transfer) {
      final categories = _selectedType == TransactionType.income
          ? ref.read(incomeCategoriesProvider)
          : ref.read(expenseCategoriesProvider);

      if (categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kategori ${_selectedType.label.toLowerCase()} belum ada. Buat kategori terlebih dahulu.',
            ),
            action: SnackBarAction(
              label: 'Buat',
              onPressed: () {
                CategoryFormSheet.show(
                  context,
                  defaultType: _selectedType == TransactionType.income
                      ? CategoryType.income
                      : CategoryType.expense,
                );
              },
            ),
          ),
        );
        return;
      }

      if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kategori transaksi wajib dipilih')),
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

    // Balance constraint check for UI warning
    int availableBalance = 0;
    String? sourceWalletName;
    bool isInsufficientBalance = false;

    if (_selectedType == TransactionType.expense) {
      final w = wallets.where((w) => w.id == _selectedWalletId).firstOrNull;
      if (w != null) {
        sourceWalletName = w.name;
        final isSameWalletEdit = widget.initialTransaction != null &&
            widget.initialTransaction!.walletId == w.id &&
            widget.initialTransaction!.type == TransactionType.expense;
        availableBalance = w.currentBalance + (isSameWalletEdit ? widget.initialTransaction!.amount : 0);
        isInsufficientBalance = inputAmount > availableBalance;
      }
    } else if (_selectedType == TransactionType.transfer) {
      final w = wallets.where((w) => w.id == _selectedSourceWalletId).firstOrNull;
      if (w != null) {
        sourceWalletName = w.name;
        final isSameSourceEdit = widget.initialTransaction != null &&
            widget.initialTransaction!.sourceWalletId == w.id &&
            widget.initialTransaction!.type == TransactionType.transfer;
        availableBalance = w.currentBalance + (isSameSourceEdit ? widget.initialTransaction!.amount : 0);
        isInsufficientBalance = inputAmount > availableBalance;
      }
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    // Batasi tinggi maksimal agar benar-benar berada di area bawah (seperti sheet di dompet dan kuota: ~50-55% layar)
    // Saat keyboard terbuka, sesuaikan dinamis di atas keyboard dengan tetap menjaga jarak dari appbar.
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
              // Handle indicator
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
                isEdit ? 'Edit Transaksi' : 'Catat Transaksi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Type Switcher: Pengeluaran | Pemasukan | Transfer
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
              const SizedBox(height: 16),

              // Nominal Input (Besar & Prominen)
              Text(
                'Nominal (Rp)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onAmountChanged,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary(context),
                ),
                decoration: const InputDecoration(
                  hintText: 'Rp 0',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              if (isInsufficientBalance && inputAmount > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.error(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Saldo ${sourceWalletName ?? "dompet"} tidak mencukupi (Tersedia: ${CurrencyFormatter.format(availableBalance)})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.error(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              // Over-Budget Warning Notice (Prinsip PRD: tidak menghakimi)
              if (isOverBudgetWarning) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.subtleBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderStrong(context), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 20, color: AppTheme.textPrimary(context)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nominal ini melebihi sisa kuota "${selectedBudget.name}" (${CurrencyFormatter.format(selectedBudget.remaining)}). Transaksi tetap dapat disimpan.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary(context),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Wallet Selector (Income / Expense)
              if (_selectedType != TransactionType.transfer) ...[
                Text(
                  'Dompet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedWalletId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: wallets.map((w) {
                    return DropdownMenuItem(
                      value: w.id,
                      child: Text(
                        '${w.name} (${CurrencyFormatter.format(w.currentBalance)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedWalletId = val),
                ),
                const SizedBox(height: 14),
              ],

              // Transfer: Source & Destination Wallets
              if (_selectedType == TransactionType.transfer) ...[
                Text(
                  'Dari Dompet (Sumber)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSourceWalletId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: wallets.map((w) {
                    return DropdownMenuItem(
                      value: w.id,
                      child: Text('${w.name} (${CurrencyFormatter.format(w.currentBalance)})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedSourceWalletId = val),
                ),
                const SizedBox(height: 12),

                Text(
                  'Ke Dompet (Tujuan)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(context)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDestinationWalletId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: wallets.map((w) {
                    return DropdownMenuItem(
                      value: w.id,
                      child: Text('${w.name} (${CurrencyFormatter.format(w.currentBalance)})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedDestinationWalletId = val),
                ),
                const SizedBox(height: 14),
              ],

              // Kuota (Khusus Pengeluaran)
              if (_selectedType == TransactionType.expense && budgets.isNotEmpty) ...[
                Text(
                  'Kuota (Opsional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedBudgetId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tanpa Kuota', overflow: TextOverflow.ellipsis),
                    ),
                    ...budgets.map((b) {
                      return DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          '${b.name} (${b.period.label} • Sisa: ${CurrencyFormatter.format(b.remaining)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _selectedBudgetId = val),
                ),
                const SizedBox(height: 14),
              ],

              // Kategori (Wajib untuk Income & Expense)
              if (_selectedType != TransactionType.transfer) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kategori (Wajib)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    if (categories.isNotEmpty)
                      InkWell(
                        onTap: () {
                          CategoryFormSheet.show(
                            context,
                            defaultType: _selectedType == TransactionType.income
                                ? CategoryType.income
                                : CategoryType.expense,
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            '+ Tambah Kategori',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (categories.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBg(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: AppTheme.textSecondary(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Belum ada kategori ${_selectedType.label.toLowerCase()}. Buat kategori terlebih dahulu.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textPrimary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            CategoryFormSheet.show(
                              context,
                              defaultType: _selectedType == TransactionType.income
                                  ? CategoryType.income
                                  : CategoryType.expense,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryButtonBg(context),
                            foregroundColor: AppTheme.primaryButtonText(context),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 14),
                          label: const Text('Buat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    isExpanded: true,
                    hint: const Text('Pilih Kategori'),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Kategori wajib dipilih';
                      }
                      return null;
                    },
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                  ),
                const SizedBox(height: 14),
              ],

              // Tanggal & Waktu
              Text(
                'Tanggal & Waktu Transaksi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.inputBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.textPrimary(context)),
                      const SizedBox(width: 12),
                      Text(
                        DateFormatter.formatDateTime(_selectedDateTime),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textSecondary(context)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Catatan (Opsional)
              Text(
                'Catatan (Opsional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Makan siang nasi padang',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 22),

              // Tombol Simpan Transaksi
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
