import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:tally/features/wallets/presentation/widgets/wallet_form_sheet.dart';
import 'package:tally/shared/models/wallet_model.dart';

class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  bool _showArchived = false;

  IconData _getWalletIcon(String type) {
    switch (type) {
      case 'bank':
        return Icons.account_balance_outlined;
      case 'e-wallet':
        return Icons.phone_android_rounded;
      case 'other':
        return Icons.credit_card_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  String _getWalletTypeLabel(String type) {
    switch (type) {
      case 'bank':
        return 'Rekening Bank';
      case 'e-wallet':
        return 'E-Wallet';
      case 'other':
        return 'Lainnya';
      default:
        return 'Tunai';
    }
  }

  void _showWalletOptions(BuildContext context, WalletModel wallet) {
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                wallet.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.black,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppTheme.black),
              title: const Text('Edit Dompet'),
              onTap: () {
                Navigator.pop(ctx);
                WalletFormSheet.show(context, wallet: wallet);
              },
            ),
            ListTile(
              leading: Icon(
                wallet.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                color: AppTheme.black,
              ),
              title: Text(wallet.isArchived ? 'Pulihkan Dompet' : 'Arsipkan Dompet'),
              subtitle: Text(
                wallet.isArchived
                    ? 'Kembalikan dompet ke daftar aktif'
                    : 'Sembunyikan dompet dari transaksi baru',
                style: const TextStyle(fontSize: 12, color: AppTheme.grey600),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await ref
                    .read(walletsProvider.notifier)
                    .toggleArchive(wallet.id, !wallet.isArchived);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.black),
              title: const Text('Hapus Dompet'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, wallet);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WalletModel wallet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.white,
        title: const Text(
          'Hapus Dompet?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Yakin ingin menghapus "${wallet.name}"? Jika dompet memiliki riwayat transaksi, disarankan untuk mengarsipkannya saja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.black,
              foregroundColor: AppTheme.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(walletsProvider.notifier).deleteWallet(wallet.id);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletsProvider);
    final totalBalance = ref.watch(totalActiveBalanceProvider);

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: RefreshIndicator(
        color: AppTheme.black,
        backgroundColor: AppTheme.white,
        onRefresh: () => ref.read(walletsProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Total Saldo Hero Card
                    Container(
                      padding: const EdgeInsets.all(22),
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
                                Icons.account_balance_wallet_rounded,
                                size: 18,
                                color: AppTheme.grey600,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Total Saldo Saat Ini',
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
                          Text(
                            CurrencyFormatter.format(totalBalance),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.black,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Controls Header: Tab Aktif/Arsip & Tambah Dompet
                    Row(
                      children: [
                        // Toggle Filter
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

                        // Tombol Tambah Dompet
                        InkWell(
                          onTap: () => WalletFormSheet.show(context),
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
                  ],
                ),
              ),
            ),

            // List Dompet
            walletsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.black,
                    strokeWidth: 2,
                  ),
                ),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(
                  child: Text('Gagal memuat dompet: $err'),
                ),
              ),
              data: (wallets) {
                final filtered = wallets
                    .where((w) => w.isArchived == _showArchived)
                    .toList();

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showArchived
                                ? Icons.inventory_2_outlined
                                : Icons.account_balance_wallet_outlined,
                            size: 48,
                            color: AppTheme.grey400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _showArchived
                                ? 'Tidak ada dompet yang diarsipkan'
                                : 'Belum ada dompet aktif',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.grey600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _showArchived
                                ? 'Dompet yang diarsipkan akan muncul di sini'
                                : 'Buat dompet pertama untuk mulai mencatat keuangan',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final wallet = filtered[index];
                        final icon = _getWalletIcon(wallet.type);
                        final typeLabel = _getWalletTypeLabel(wallet.type);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.grey200),
                          ),
                          child: InkWell(
                            onTap: () => _showWalletOptions(context, wallet),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Icon Container
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppTheme.grey100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(icon, color: AppTheme.black, size: 22),
                                  ),
                                  const SizedBox(width: 14),

                                  // Name & Type
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          wallet.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          typeLabel,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.grey600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Balance & Action Icon
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(wallet.currentBalance),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: wallet.currentBalance < 0
                                              ? AppTheme.black
                                              : AppTheme.black,
                                        ),
                                      ),
                                      if (wallet.isArchived)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Arsip',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.grey400,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.more_vert_rounded,
                                    size: 18,
                                    color: AppTheme.grey400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x0A000000),
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
