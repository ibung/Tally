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
  late BudgetPeriod _selectedPeriod;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  static const _dailySuggestions = [
    'Makan',
    'Kopi & Jajan',
    'Transportasi',
    'Bensin',
    'Belanja Harian',
  ];

  static const _weeklySuggestions = [
    'Belanja Mingguan',
    'Uang Jajan Minggu Ini',
    'Makan & Hangout',
    'Bensin Mingguan',
  ];

  static const _monthlySuggestions = [
    'Biaya Hidup Bulanan',
    'Belanja Bulanan',
    'Kuota Bulanan',
    'Tagihan & Langganan',
  ];

  static const _customSuggestions = [
    'Liburan',
    'Renovasi Rumah',
    'Event Khusus',
    'Proyek Singkat',
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

    _selectedPeriod = budget?.period ?? BudgetPeriod.daily;

    final now = DateTime.now();
    if (budget != null) {
      _startDate = DateTime.tryParse(budget.startDate) ?? now;
      if (budget.endDate != null) {
        _endDate = DateTime.tryParse(budget.endDate!);
      } else if (_selectedPeriod == BudgetPeriod.weekly) {
        _endDate = _startDate.add(const Duration(days: 6));
      } else if (_selectedPeriod == BudgetPeriod.monthly) {
        _endDate = DateTime(_startDate.year, _startDate.month + 1, 0);
      }
    } else {
      _startDate = now;
      _applyDefaultDatesForPeriod(_selectedPeriod, preserveStartDate: false);
    }
  }

  void _applyDefaultDatesForPeriod(BudgetPeriod period, {bool preserveStartDate = true}) {
    final now = DateTime.now();
    if (!preserveStartDate) {
      if (period == BudgetPeriod.monthly) {
        // Melacak bulan realtime yang ada saat ini
        _startDate = DateTime(now.year, now.month, 1);
      } else {
        _startDate = now;
      }
    }

    if (period == BudgetPeriod.daily) {
      _endDate = null;
    } else if (period == BudgetPeriod.weekly) {
      // Otomatis 7 hari (startDate s/d startDate + 6 hari)
      _endDate = _startDate.add(const Duration(days: 6));
    } else if (period == BudgetPeriod.monthly) {
      // Otomatis sampai akhir bulan berjalan
      _endDate = DateTime(_startDate.year, _startDate.month + 1, 0);
    } else if (period == BudgetPeriod.custom) {
      // Bebas: default fleksibel (misal 30 hari atau bebas diatur pengguna)
      _endDate = _startDate.add(const Duration(days: 30));
    }
  }

  void _onPeriodChanged(BudgetPeriod period) {
    if (_selectedPeriod == period) return;
    setState(() {
      _selectedPeriod = period;
      _applyDefaultDatesForPeriod(period, preserveStartDate: false);
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.textPrimary(context),
              onPrimary: AppTheme.primaryButtonText(context),
              surface: AppTheme.cardBg(context),
              onSurface: AppTheme.textPrimary(context),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Otomatis sesuaikan endDate sesuai periode
        if (_selectedPeriod == BudgetPeriod.weekly) {
          _endDate = _startDate.add(const Duration(days: 6));
        } else if (_selectedPeriod == BudgetPeriod.monthly) {
          _endDate = DateTime(_startDate.year, _startDate.month + 1, 0);
        } else if (_selectedPeriod == BudgetPeriod.custom) {
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final initial = _endDate ?? _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(_startDate) ? _startDate : initial,
      firstDate: _startDate,
      lastDate: DateTime(2040),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.textPrimary(context),
              onPrimary: AppTheme.primaryButtonText(context),
              surface: AppTheme.cardBg(context),
              onSurface: AppTheme.textPrimary(context),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
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

  List<String> get _currentSuggestions {
    switch (_selectedPeriod) {
      case BudgetPeriod.weekly:
        return _weeklySuggestions;
      case BudgetPeriod.monthly:
        return _monthlySuggestions;
      case BudgetPeriod.custom:
        return _customSuggestions;
      case BudgetPeriod.daily:
        return _dailySuggestions;
    }
  }

  String get _limitLabel {
    switch (_selectedPeriod) {
      case BudgetPeriod.weekly:
        return 'Batas Maksimal Mingguan (Rp)';
      case BudgetPeriod.monthly:
        return 'Batas Maksimal Bulanan (Rp)';
      case BudgetPeriod.custom:
        return 'Batas Maksimal Kuota (Rp)';
      case BudgetPeriod.daily:
        return 'Batas Maksimal per Hari (Rp)';
    }
  }

  String get _periodInfoText {
    switch (_selectedPeriod) {
      case BudgetPeriod.weekly:
        return 'Kuota ini melacak pengeluaran selama 1 minggu (7 hari) atau sesuai rentang tanggal yang dipilih.';
      case BudgetPeriod.monthly:
        return 'Kuota ini melacak pengeluaran dari bulan realtime atau rentang tanggal yang dipilih.';
      case BudgetPeriod.custom:
        return 'Kuota bebas melacak pengeluaran dalam rentang tanggal fleksibel yang Anda tentukan sendiri.';
      case BudgetPeriod.daily:
        return 'Kuota ini dihitung per hari tanpa rollover. Penggunaan akan otomatis direset setiap hari.';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final name = _nameController.text.trim();
    final limit = CurrencyFormatter.parseInt(_limitController.text);
    final startDateStr = DateFormatter.toLocalDate(_startDate);
    final endDateStr = _endDate != null ? DateFormatter.toLocalDate(_endDate!) : null;

    try {
      if (widget.initialBudget != null) {
        await ref.read(budgetsProvider.notifier).updateBudget(
              id: widget.initialBudget!.id,
              name: name,
              dailyLimit: limit,
              period: _selectedPeriod,
              startDate: startDateStr,
              endDate: endDateStr,
            );
      } else {
        await ref.read(budgetsProvider.notifier).createBudget(
              name: name,
              dailyLimit: limit,
              period: _selectedPeriod,
              startDate: startDateStr,
              endDate: endDateStr,
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
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Batasi tinggi sheet agar mingguan & bulanan konsisten dengan harian (tidak mencot ke atas layar)
    final maxSheetHeight = screenHeight * 0.70;
    final calculatedMaxHeight = bottomInset > 0
        ? (screenHeight - topPadding - 16)
        : maxSheetHeight;

    return Container(
      constraints: BoxConstraints(
        maxHeight: calculatedMaxHeight,
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
              const SizedBox(height: 16),

              // Title
              Text(
                isEdit ? 'Edit Kuota' : 'Tambah Kuota Baru',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 18),

              // Pilihan Periode Kuota (Harian, Mingguan, Bulanan)
              Text(
                'Periode Kuota',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.chipBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(
                  children: BudgetPeriod.values.map((period) {
                    final isSelected = _selectedPeriod == period;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _onPeriodChanged(period),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.cardBg(context) : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppTheme.isDark(context)
                                          ? const Color(0x30000000)
                                          : const Color(0x0A000000),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              period.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.textPrimary(context)
                                    : AppTheme.textSecondary(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // Nama Kuota
              Text(
                'Nama Kuota',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: _selectedPeriod == BudgetPeriod.monthly
                      ? 'Contoh: Biaya Hidup Bulanan, Kuota Belanja'
                      : _selectedPeriod == BudgetPeriod.weekly
                          ? 'Contoh: Belanja Mingguan, Uang Jajan'
                          : _selectedPeriod == BudgetPeriod.custom
                              ? 'Contoh: Liburan, Renovasi, Event'
                              : 'Contoh: Makan Siang, Kopi, Jajan',
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
                children: _currentSuggestions.map((suggestion) {
                  return InkWell(
                    onTap: () => setState(() => _nameController.text = suggestion),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.subtleBg(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border(context)),
                      ),
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Pilihan Tanggal & Sampai Tanggal (untuk Mingguan & Bulanan)
              if (_selectedPeriod != BudgetPeriod.daily) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rentang Tanggal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    Text(
                      _selectedPeriod == BudgetPeriod.weekly
                          ? 'Otomatis 7 Hari'
                          : _selectedPeriod == BudgetPeriod.monthly
                              ? 'Realtime Bulan'
                              : 'Bebas Pilih Rentang',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Mulai Tanggal
                    Expanded(
                      child: InkWell(
                        onTap: _pickStartDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.subtleBg(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mulai Tanggal',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      DateFormatter.formatDate(_startDate),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary(context),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sampai Tanggal
                    Expanded(
                      child: InkWell(
                        onTap: _pickEndDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.subtleBg(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sampai Tanggal',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.event_available_rounded,
                                    size: 14,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _endDate != null
                                          ? DateFormatter.formatDate(_endDate!)
                                          : 'Pilih Tanggal',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary(context),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedPeriod == BudgetPeriod.weekly
                      ? 'Sampai tanggal diisi otomatis 7 hari, tetap bisa Anda sesuaikan jika ingin cut-off berbeda.'
                      : 'Secara realtime melacak bulan berjalan, atau sesuaikan tanggal bila siklus gajian berbeda.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Batas Maksimal (Rp)
              Text(
                _limitLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onLimitChanged,
                decoration: InputDecoration(
                  hintText: _selectedPeriod == BudgetPeriod.monthly
                      ? 'Rp 2.500.000'
                      : _selectedPeriod == BudgetPeriod.weekly
                          ? 'Rp 500.000'
                          : 'Rp 50.000',
                ),
                validator: (val) {
                  final amount = CurrencyFormatter.parseInt(val ?? '');
                  if (amount <= 0) {
                    return 'Batas kuota harus lebih besar dari 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Info Box Penjelasan Periode
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.subtleBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppTheme.textSecondary(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _periodInfoText,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary(context),
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
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryButtonText(context),
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
