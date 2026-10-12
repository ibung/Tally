import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/history/presentation/providers/history_providers.dart';
import 'package:tally/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:tally/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:tally/shared/models/transaction_model.dart';
import 'package:tally/shared/widgets/transaction_detail_dialog.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(historyFilterProvider);
    _searchController = TextEditingController(text: filter.searchQuery ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(historyFilterProvider.notifier).update((state) {
      return state.copyWith(searchQuery: query.trim());
    });
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(historyFilterProvider.notifier).update((state) {
      return state.copyWith(clearSearch: true);
    });
  }

  void _setTypeFilter(TransactionType? type) {
    ref.read(historyFilterProvider.notifier).update((state) {
      if (type == null || state.type == type) {
        return state.copyWith(clearType: true);
      }
      return state.copyWith(type: type);
    });
  }

  void _clearWalletFilter() {
    ref.read(historyFilterProvider.notifier).update((state) {
      return state.copyWith(clearWallet: true);
    });
  }

  void _clearDateFilter() {
    ref.read(historyFilterProvider.notifier).update((state) {
      return state.copyWith(clearStartDate: true, clearEndDate: true);
    });
  }

  void _resetAllFilters() {
    _searchController.clear();
    ref.read(historyFilterProvider.notifier).state = const HistoryFilterState();
  }

  IconData _getTransactionIcon(TransactionModel tx) {
    if (tx.isCorrection) {
      return Icons.tune_rounded;
    }
    if (tx.type == TransactionType.transfer) {
      return Icons.swap_horiz_rounded;
    }
    if (tx.type == TransactionType.income) {
      return Icons.arrow_downward_rounded;
    }

    switch (tx.categoryIcon) {
      case 'fastfood':
      case 'restaurant':
      case 'food':
        return Icons.restaurant_outlined;
      case 'directions_car':
      case 'transport':
        return Icons.directions_car_outlined;
      case 'shopping_cart':
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'receipt':
      case 'bill':
        return Icons.receipt_outlined;
      case 'movie':
      case 'entertainment':
        return Icons.movie_outlined;
      case 'health':
      case 'medical_services':
        return Icons.medical_services_outlined;
      case 'school':
      case 'education':
        return Icons.school_outlined;
      default:
        return Icons.arrow_upward_rounded;
    }
  }

  Map<String, List<TransactionModel>> _groupTransactionsByDate(
      List<TransactionModel> list) {
    final grouped = <String, List<TransactionModel>>{};
    for (final tx in list) {
      grouped.putIfAbsent(tx.localDate, () => []).add(tx);
    }
    return grouped;
  }

  String _formatDateHeader(String localDate) {
    final parsed = DateFormatter.parseLocalDate(localDate);
    final relative = DateFormatter.formatRelative(parsed);
    final formatted = DateFormatter.formatDate(parsed);

    if (relative == 'Hari ini' || relative == 'Kemarin' || relative == 'Besok') {
      return '$relative, $formatted';
    }
    return DateFormatter.formatFullDay(parsed);
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FilterBottomSheet(
        onReset: _resetAllFilters,
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, TransactionModel tx) {
    showTransactionDetailDialog(context, tx, _getTransactionIcon(tx));
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(historyFilterProvider);
    final transactionsAsync = ref.watch(historyTransactionsProvider);
    final summary = ref.watch(historySummaryProvider);
    final walletsAsync = ref.watch(walletsProvider);

    // Dapatkan nama dompet terpilih jika ada filter dompet
    String? selectedWalletName;
    if (filter.walletId != null) {
      final wallets = walletsAsync.valueOrNull ?? [];
      final match = wallets.where((w) => w.id == filter.walletId);
      if (match.isNotEmpty) {
        selectedWalletName = match.first.name;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: RefreshIndicator(
        color: AppTheme.textPrimary(context),
        backgroundColor: AppTheme.cardBg(context),
        onRefresh: () => ref.read(historyTransactionsProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Top App Bar & Search Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search Bar & Filter Button
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.chipBg(context),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textPrimary(context),
                              ),
                              decoration: InputDecoration(
                                hintText: 'Cari catatan, kategori, dompet...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textMuted(context),
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: AppTheme.textSecondary(context),
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear_rounded,
                                          size: 18,
                                          color: AppTheme.textSecondary(context),
                                        ),
                                        onPressed: _clearSearch,
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Filter Trigger Button
                        InkWell(
                          onTap: () => _showFilterSheet(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: filter.hasActiveFilter
                                  ? AppTheme.primaryButtonBg(context)
                                  : AppTheme.chipBg(context),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 22,
                                  color: filter.hasActiveFilter
                                      ? AppTheme.primaryButtonText(context)
                                      : AppTheme.textPrimary(context),
                                ),
                                if (filter.hasActiveFilter)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cardBg(context),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: AppTheme.textPrimary(context),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _QuickChip(
                            label: 'Semua',
                            selected: filter.type == null,
                            onTap: () => _setTypeFilter(null),
                          ),
                          const SizedBox(width: 8),
                          _QuickChip(
                            label: 'Pengeluaran',
                            selected: filter.type == TransactionType.expense,
                            onTap: () => _setTypeFilter(TransactionType.expense),
                          ),
                          const SizedBox(width: 8),
                          _QuickChip(
                            label: 'Pemasukan',
                            selected: filter.type == TransactionType.income,
                            onTap: () => _setTypeFilter(TransactionType.income),
                          ),
                          const SizedBox(width: 8),
                          _QuickChip(
                            label: 'Transfer',
                            selected: filter.type == TransactionType.transfer,
                            onTap: () => _setTypeFilter(TransactionType.transfer),
                          ),

                          // Active Date Chip
                          if (filter.startDate != null || filter.endDate != null) ...[
                            const SizedBox(width: 8),
                            _RemovableChip(
                              label: filter.startDate != null && filter.endDate != null
                                  ? '${DateFormatter.formatDate(filter.startDate!)} - ${DateFormatter.formatDate(filter.endDate!)}'
                                  : filter.startDate != null
                                      ? 'Dari ${DateFormatter.formatDate(filter.startDate!)}'
                                      : 'Sampai ${DateFormatter.formatDate(filter.endDate!)}',
                              onRemove: _clearDateFilter,
                            ),
                          ],

                          // Active Wallet Chip
                          if (selectedWalletName != null) ...[
                            const SizedBox(width: 8),
                            _RemovableChip(
                              label: selectedWalletName,
                              onRemove: _clearWalletFilter,
                            ),
                          ],

                          // Reset All Chip
                          if (filter.hasActiveFilter) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _resetAllFilters,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.chipBg(context),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.restart_alt_rounded,
                                        size: 14, color: AppTheme.textSecondary(context)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Reset',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Summary Strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border(context)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 16,
                                color: AppTheme.textSecondary(context),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${summary.count} Transaksi',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '+${CurrencyFormatter.format(summary.totalIncome)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('•', style: TextStyle(color: AppTheme.textMuted(context))),
                              const SizedBox(width: 8),
                              Text(
                                '-${CurrencyFormatter.format(summary.totalExpense)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            // Transactions List
            transactionsAsync.when(
              loading: () => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Gagal memuat transaksi: $err',
                      style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
                    ),
                  ),
                ),
              ),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _EmptyHistoryState(
                      hasFilter: filter.hasActiveFilter,
                      onResetFilter: _resetAllFilters,
                    ),
                  );
                }

                final grouped = _groupTransactionsByDate(transactions);
                final dateKeys = grouped.keys.toList();

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final dateKey = dateKeys[index];
                        final items = grouped[dateKey]!;

                        // Total net for this specific day (koreksi saldo dikecualikan dari arus kas)
                        final dailyNet = items.fold<int>(0, (sum, tx) {
                          if (tx.isCorrection) return sum;
                          if (tx.type == TransactionType.income) return sum + tx.amount;
                          if (tx.type == TransactionType.expense) return sum - tx.amount;
                          return sum;
                        });

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Date Group Header
                            Padding(
                              padding: const EdgeInsets.only(top: 16, bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 13,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatDateHeader(dateKey),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary(context),
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    dailyNet >= 0
                                        ? '+${CurrencyFormatter.format(dailyNet)}'
                                        : '-${CurrencyFormatter.format(dailyNet.abs())}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: dailyNet >= 0
                                          ? AppTheme.textPrimary(context)
                                          : AppTheme.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Items under this date
                            ...items.map(
                              (tx) => _HistoryListItem(
                                tx: tx,
                                icon: _getTransactionIcon(tx),
                                onTap: () => _showTransactionDetails(context, tx),
                                onDelete: () {
                                  ref.read(transactionsProvider.notifier).deleteTransaction(tx.id);
                                },
                              ),
                            ),
                          ],
                        );
                      },
                      childCount: dateKeys.length,
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper Widgets
// ---------------------------------------------------------------------------

class _QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickChip({
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryButtonBg(context) : AppTheme.cardBg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primaryButtonBg(context) : AppTheme.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.primaryButtonText(context) : AppTheme.textPrimary(context),
          ),
        ),
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _RemovableChip({
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppTheme.chipBg(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 14, color: AppTheme.textSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryListItem extends StatelessWidget {
  final TransactionModel tx;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _HistoryListItem({
    required this.tx,
    required this.icon,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrection = tx.isCorrection;
    final title = isCorrection
        ? (tx.note ?? 'Koreksi Saldo')
        : tx.type == TransactionType.transfer
            ? '${tx.sourceWalletName ?? "Dompet"} ➔ ${tx.destinationWalletName ?? "Dompet"}'
            : (tx.categoryName ??
                (tx.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran'));

    final amountText = tx.type == TransactionType.income
        ? '+${CurrencyFormatter.format(tx.amount)}'
        : tx.type == TransactionType.expense
            ? '-${CurrencyFormatter.format(tx.amount)}'
            : CurrencyFormatter.format(tx.amount);

    final itemWidget = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.chipBg(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppTheme.textPrimary(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (tx.type != TransactionType.transfer && tx.walletName != null)
                          Text(
                            tx.walletName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (tx.budgetName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.chipBg(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tx.budgetName!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary(context),
                              ),
                            ),
                          ),
                        if (tx.note != null && tx.note!.isNotEmpty && !isCorrection)
                          Text(
                            '• "${tx.note!}"',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary(context),
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          '• ${DateFormatter.formatTime(tx.occurredAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tx.type == TransactionType.income
                      ? AppTheme.textPrimary(context)
                      : tx.type == TransactionType.expense
                          ? (AppTheme.isDark(context) ? const Color(0xFFD4D4D8) : AppTheme.grey800)
                          : AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onDelete == null) return itemWidget;

    return Dismissible(
      key: Key('tx_${tx.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
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
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Batal', style: TextStyle(color: AppTheme.textSecondary(context))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error(context),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete!(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.error(context).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        child: Icon(Icons.delete_outline_rounded, color: AppTheme.error(context), size: 22),
      ),
      child: itemWidget,
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onResetFilter;

  const _EmptyHistoryState({
    required this.hasFilter,
    required this.onResetFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.chipBg(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilter ? Icons.search_off_rounded : Icons.receipt_long_outlined,
              size: 32,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter
                ? 'Tidak ada transaksi ditemukan'
                : 'Belum ada riwayat transaksi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter
                ? 'Coba sesuaikan kata kunci atau bersihkan filter yang aktif.'
                : 'Catat pemasukan, pengeluaran, atau transfer untuk melihat riwayat di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary(context),
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onResetFilter,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary(context),
                side: BorderSide(color: AppTheme.borderStrong(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Reset Filter'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter Bottom Sheet
// ---------------------------------------------------------------------------

class _FilterBottomSheet extends ConsumerStatefulWidget {
  final VoidCallback onReset;

  const _FilterBottomSheet({required this.onReset});

  @override
  ConsumerState<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<_FilterBottomSheet> {
  late TransactionType? _type;
  late String? _walletId;
  late DateTime? _startDate;
  late DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(historyFilterProvider);
    _type = filter.type;
    _walletId = filter.walletId;
    _startDate = filter.startDate;
    _endDate = filter.endDate;
  }

  void _applyRangePreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      switch (preset) {
        case 'this_month':
          _startDate = DateTime(today.year, today.month, 1);
          _endDate = today;
          break;
        case 'last_7_days':
          _startDate = today.subtract(const Duration(days: 6));
          _endDate = today;
          break;
        case 'last_30_days':
          _startDate = today.subtract(const Duration(days: 29));
          _endDate = today;
          break;
        case 'all':
        default:
          _startDate = null;
          _endDate = null;
          break;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final initialRange = _startDate != null && _endDate != null
        ? DateTimeRange(start: _startDate!, end: _endDate!)
        : null;

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        final isDark = AppTheme.isDark(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: isDark ? Brightness.dark : Brightness.light,
              primary: AppTheme.textPrimary(context),
              onPrimary: AppTheme.bg(context),
              surface: AppTheme.cardBg(context),
              onSurface: AppTheme.textPrimary(context),
              secondary: AppTheme.textPrimary(context),
              onSecondary: AppTheme.bg(context),
              error: Colors.red,
              onError: AppTheme.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _applyFilter() {
    ref.read(historyFilterProvider.notifier).update((state) {
      return state.copyWith(
        type: _type,
        clearType: _type == null,
        walletId: _walletId,
        clearWallet: _walletId == null,
        startDate: _startDate,
        clearStartDate: _startDate == null,
        endDate: _endDate,
        clearEndDate: _endDate == null,
      );
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider).valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Transaksi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              TextButton(
                onPressed: () {
                  widget.onReset();
                  setState(() {
                    _type = null;
                    _walletId = null;
                    _startDate = null;
                    _endDate = null;
                  });
                },
                child: Text(
                  'Reset',
                  style: TextStyle(color: AppTheme.textSecondary(context), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Rentang Waktu
          Text(
            'Rentang Tanggal',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Semua Waktu',
                selected: _startDate == null && _endDate == null,
                onTap: () => _applyRangePreset('all'),
              ),
              _FilterChip(
                label: 'Bulan Ini',
                selected: false,
                onTap: () => _applyRangePreset('this_month'),
              ),
              _FilterChip(
                label: '7 Hari Terakhir',
                selected: false,
                onTap: () => _applyRangePreset('last_7_days'),
              ),
              _FilterChip(
                label: '30 Hari Terakhir',
                selected: false,
                onTap: () => _applyRangePreset('last_30_days'),
              ),
              _FilterChip(
                label: _startDate != null && _endDate != null
                    ? '${DateFormatter.formatDate(_startDate!)} - ${DateFormatter.formatDate(_endDate!)}'
                    : 'Pilih Rentang...',
                selected: _startDate != null && _endDate != null,
                onTap: _pickCustomRange,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Jenis Transaksi
          Text(
            'Jenis Transaksi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'Semua',
                selected: _type == null,
                onTap: () => setState(() => _type = null),
              ),
              _FilterChip(
                label: 'Pengeluaran',
                selected: _type == TransactionType.expense,
                onTap: () => setState(() => _type = TransactionType.expense),
              ),
              _FilterChip(
                label: 'Pemasukan',
                selected: _type == TransactionType.income,
                onTap: () => setState(() => _type = TransactionType.income),
              ),
              _FilterChip(
                label: 'Transfer',
                selected: _type == TransactionType.transfer,
                onTap: () => setState(() => _type = TransactionType.transfer),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Dompet
          Text(
            'Dompet',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Semua Dompet',
                selected: _walletId == null,
                onTap: () => setState(() => _walletId = null),
              ),
              ...wallets.where((w) => !w.isArchived).map(
                    (w) => _FilterChip(
                      label: w.name,
                      selected: _walletId == w.id,
                      onTap: () => setState(() => _walletId = w.id),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 24),

          // Apply button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryButtonBg(context),
              foregroundColor: AppTheme.primaryButtonText(context),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _applyFilter,
            child: const Text(
              'Terapkan Filter',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(height: 10),
        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryButtonBg(context) : AppTheme.chipBg(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.primaryButtonText(context) : AppTheme.textPrimary(context),
          ),
        ),
      ),
    );
  }
}
