import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:tally/features/transactions/presentation/widgets/transaction_form_sheet.dart';
import 'package:tally/shared/models/transaction_model.dart';

/// Shows a premium center-screen detail dialog for a transaction.
/// Replaces the previous bottom-sheet pattern.
Future<void> showTransactionDetailDialog(
  BuildContext context,
  TransactionModel tx,
  IconData icon,
) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Detail Transaksi',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      return _TransactionDetailDialog(tx: tx, icon: icon);
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _TransactionDetailDialog extends ConsumerWidget {
  final TransactionModel tx;
  final IconData icon;

  const _TransactionDetailDialog({required this.tx, required this.icon});

  String _amountText() {
    return switch (tx.type) {
      TransactionType.income => '+${CurrencyFormatter.format(tx.amount)}',
      TransactionType.expense => '-${CurrencyFormatter.format(tx.amount)}',
      _ => CurrencyFormatter.format(tx.amount),
    };
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Transaksi?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
        ),
        content: Text(
          'Yakin ingin menghapus transaksi sebesar ${CurrencyFormatter.format(tx.amount)}?',
          style: TextStyle(color: AppTheme.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: AppTheme.textSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryButtonBg(context),
              foregroundColor: AppTheme.primaryButtonText(context),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(transactionsProvider.notifier).deleteTransaction(tx.id);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = AppTheme.isDark(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.border(context)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? const Color(0x33000000) : const Color(0x1A000000),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header band ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F1F1F) : AppTheme.black,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 22, color: AppTheme.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tx.type.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _amountText(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close button
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: AppTheme.white),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Detail rows ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Waktu',
                        value: DateFormatter.formatDateTime(tx.occurredAt),
                      ),
                      if (tx.type == TransactionType.transfer) ...[
                        _DetailRow(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Dompet Asal',
                          value: tx.sourceWalletName ?? '-',
                        ),
                        _DetailRow(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Dompet Tujuan',
                          value: tx.destinationWalletName ?? '-',
                        ),
                      ] else ...[
                        _DetailRow(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Dompet',
                          value: tx.walletName ?? '-',
                        ),
                      ],
                      if (tx.categoryName != null)
                        _DetailRow(
                          icon: Icons.category_outlined,
                          label: 'Kategori',
                          value: tx.categoryName!,
                        ),
                      if (tx.budgetName != null)
                        _DetailRow(
                          icon: Icons.pie_chart_outline_rounded,
                          label: 'Kuota Harian',
                          value: tx.budgetName!,
                        ),
                      if (tx.note != null && tx.note!.isNotEmpty)
                        _DetailRow(
                          icon: Icons.notes_rounded,
                          label: 'Catatan',
                          value: tx.note!,
                        ),
                    ],
                  ),
                ),

                // ── Action buttons ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary(context),
                            side: BorderSide(color: AppTheme.border(context)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 17),
                          label: const Text('Hapus'),
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmDelete(context, ref);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryButtonBg(context),
                            foregroundColor: AppTheme.primaryButtonText(context),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Edit'),
                          onPressed: () {
                            Navigator.pop(context);
                            TransactionFormSheet.show(context, transaction: tx);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppTheme.textSecondary(context)),
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
