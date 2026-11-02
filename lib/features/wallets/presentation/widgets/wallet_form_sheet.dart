import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:tally/shared/models/wallet_model.dart';

class WalletFormSheet extends ConsumerStatefulWidget {
  final WalletModel? initialWallet;
  final DateTime? initialDate;

  const WalletFormSheet({super.key, this.initialWallet, this.initialDate});

  static Future<void> show(
    BuildContext context, {
    WalletModel? wallet,
    DateTime? initialDate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WalletFormSheet(
        initialWallet: wallet,
        initialDate: initialDate,
      ),
    );
  }

  @override
  ConsumerState<WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends ConsumerState<WalletFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late String _selectedType;
  late DateTime _correctionDate;
  bool _isLoading = false;

  static const _walletTypes = [
    (key: 'cash', label: 'Tunai', icon: Icons.payments_outlined),
    (key: 'bank', label: 'Bank', icon: Icons.account_balance_outlined),
    (key: 'e-wallet', label: 'E-Wallet', icon: Icons.phone_android_rounded),
    (key: 'other', label: 'Lainnya', icon: Icons.credit_card_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final wallet = widget.initialWallet;
    _nameController = TextEditingController(text: wallet?.name ?? '');
    _selectedType = wallet?.type ?? 'cash';
    _correctionDate = widget.initialDate ?? DateTime.now();

    final initialBalance = widget.initialWallet != null
        ? widget.initialWallet!.currentBalance
        : (wallet?.openingBalance ?? 0);
    _balanceController = TextEditingController(
      text: initialBalance > 0 ? CurrencyFormatter.format(initialBalance) : '',
    );

    if (widget.initialWallet != null && widget.initialDate != null) {
      _loadBalanceForDate(widget.initialDate!);
    }
  }

  Future<void> _loadBalanceForDate(DateTime date) async {
    if (widget.initialWallet == null) return;
    final repo = ref.read(walletRepositoryProvider);
    final localDate = DateFormatter.toLocalDate(date);
    final bal = await repo.getWalletBalance(widget.initialWallet!.id, upToLocalDate: localDate);
    if (mounted) {
      setState(() {
        _balanceController.value = TextEditingValue(
          text: bal > 0 ? CurrencyFormatter.format(bal) : '',
          selection: TextSelection.collapsed(
            offset: (bal > 0 ? CurrencyFormatter.format(bal) : '').length,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _onBalanceChanged(String value) {
    final parsed = CurrencyFormatter.parseInt(value);
    final formatted = parsed > 0 ? CurrencyFormatter.format(parsed) : '';
    if (formatted != value) {
      _balanceController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _pickCorrectionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _correctionDate,
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
        _correctionDate = picked;
      });
      await _loadBalanceForDate(picked);
    }
  }

  String _formatCorrectionDate(DateTime date) {
    final relative = DateFormatter.formatRelative(date);
    final fullDate = DateFormatter.formatDate(date);
    if (relative == 'Hari ini' || relative == 'Kemarin' || relative == 'Besok') {
      return '$relative • $fullDate';
    }
    return DateFormatter.formatFullDateWithDay(date);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final name = _nameController.text.trim();
    final targetBalance = CurrencyFormatter.parseInt(_balanceController.text);

    try {
      if (widget.initialWallet != null) {
        await ref.read(walletsProvider.notifier).updateWallet(
              id: widget.initialWallet!.id,
              name: name,
              type: _selectedType,
              targetBalance: targetBalance,
              correctionDate: _correctionDate,
            );
      } else {
        await ref.read(walletsProvider.notifier).createWallet(
              name: name,
              type: _selectedType,
              openingBalance: targetBalance,
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
    final isEdit = widget.initialWallet != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: bottomInset + 24,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: AppTheme.border(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                isEdit ? 'Edit Dompet' : 'Tambah Dompet Baru',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),

              // Nama Dompet
              Text(
                'Nama Dompet',
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
                decoration: const InputDecoration(
                  hintText: 'Contoh: BCA, Dompet Saku, GoPay',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama dompet tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Jenis Dompet
              Text(
                'Jenis Dompet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _walletTypes.map((type) {
                  final isSelected = _selectedType == type.key;
                  return InkWell(
                    onTap: () => setState(() => _selectedType = type.key),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryButtonBg(context) : AppTheme.subtleBg(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryButtonBg(context) : AppTheme.border(context),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type.icon,
                            size: 18,
                            color: isSelected ? AppTheme.primaryButtonText(context) : AppTheme.textPrimary(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? AppTheme.primaryButtonText(context) : AppTheme.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Saldo Awal / Saldo Dompet
              Text(
                isEdit ? 'Saldo Dompet (Rp)' : 'Saldo Awal (Rp)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              if (isEdit) ...[
                const SizedBox(height: 4),
                Text(
                  'Perubahan nominal saldo akan dicatat otomatis sebagai riwayat Koreksi Saldo.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onBalanceChanged,
                decoration: const InputDecoration(
                  hintText: 'Rp 0',
                ),
              ),
              if (isEdit) ...[
                const SizedBox(height: 18),
                Text(
                  'Tanggal Koreksi Saldo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pilih tanggal riwayat saldo yang ingin Anda sesuaikan.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickCorrectionDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.subtleBg(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 17,
                          color: AppTheme.textPrimary(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _formatCorrectionDate(_correctionDate),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          color: AppTheme.textSecondary(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),

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
                        isEdit ? 'Simpan Perubahan' : 'Buat Dompet',
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
