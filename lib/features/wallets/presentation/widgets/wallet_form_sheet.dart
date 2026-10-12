import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:tally/shared/models/wallet_model.dart';

class WalletFormSheet extends ConsumerStatefulWidget {
  final WalletModel? initialWallet;

  const WalletFormSheet({super.key, this.initialWallet});

  static Future<void> show(BuildContext context, {WalletModel? wallet}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WalletFormSheet(initialWallet: wallet),
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

    final initialBalance = wallet?.openingBalance ?? 0;
    _balanceController = TextEditingController(
      text: initialBalance > 0 ? CurrencyFormatter.format(initialBalance) : '',
    );
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final name = _nameController.text.trim();
    final openingBalance = CurrencyFormatter.parseInt(_balanceController.text);

    try {
      if (widget.initialWallet != null) {
        await ref.read(walletsProvider.notifier).updateWallet(
              id: widget.initialWallet!.id,
              name: name,
              type: _selectedType,
              openingBalance: openingBalance,
            );
      } else {
        await ref.read(walletsProvider.notifier).createWallet(
              name: name,
              type: _selectedType,
              openingBalance: openingBalance,
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

              // Saldo Awal
              Text(
                'Saldo Awal (Rp)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
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
