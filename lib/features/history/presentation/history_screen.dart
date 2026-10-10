import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/history/presentation/providers/history_providers.dart';
import 'package:tally/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:tally/features/transactions/presentation/widgets/transaction_form_sheet.dart';
import 'package:tally/features/wallets/presentation/providers/wallet_providers.dart';
import 'package:tally/shared/models/transaction_model.dart';

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
      if (state.type == type) {
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            const SizedBox(height: 20),

            // Header Icon & Amount
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getTransactionIcon(tx),
                    size: 24,
                    color: AppTheme.black,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.type.label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.grey600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tx.type == TransactionType.income
                            ? '+${CurrencyFormatter.format(tx.amount)}'
                            : tx.type == TransactionType.expense
                                ? '-${CurrencyFormatter.format(tx.amount)}'
                                : CurrencyFormatter.format(tx.amount),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppTheme.grey200, height: 1),
            const SizedBox(height: 16),

            // Details rows
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

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.black,
                      side: const BorderSide(color: AppTheme.grey200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Hapus'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDelete(context, tx);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.black,
                      foregroundColor: AppTheme.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      TransactionFormSheet.show(context, transaction: tx);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, TransactionModel tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Transaksi?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Yakin ingin menghapus transaksi sebesar ${CurrencyFormatter.format(tx.amount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.grey600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.black,
              foregroundColor: AppTheme.white,
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
      backgroundColor: AppTheme.white,
      body: RefreshIndicator(
        color: AppTheme.black,
        backgroundColor: AppTheme.white,
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
                              color: AppTheme.grey100,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.black,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Cari catatan, kategori, dompet...',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.grey600,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: AppTheme.grey600,
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear_rounded,
                                          size: 18,
                                          color: AppTheme.grey600,
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
                                  ? AppTheme.black
                                  : AppTheme.grey100,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 22,
                                  color: filter.hasActiveFilter
                                      ? AppTheme.white
                                      : AppTheme.black,
                                ),
                                if (filter.hasActiveFilter)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppTheme.black,
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
                                  color: AppTheme.grey100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.restart_alt_rounded,
                                        size: 14, color: AppTheme.grey600),
                                    SizedBox(width: 4),
                                    Text(
                                      'Reset',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.grey600,
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
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.grey200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                size: 16,
                                color: AppTheme.grey600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${summary.count} Transaksi',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.grey800,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '+${CurrencyFormatter.format(summary.totalIncome)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('•', style: TextStyle(color: AppTheme.grey400)),
                              const SizedBox(width: 8),
                              Text(
                                '-${CurrencyFormatter.format(summary.totalExpense)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.grey600,
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
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.black,
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
                      style: const TextStyle(color: AppTheme.grey600, fontSize: 13),
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

                        // Total net for this specific day
                        final dailyNet = items.fold<int>(0, (sum, tx) {
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
                                      const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 13,
                                        color: AppTheme.grey600,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatDateHeader(dateKey),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.black,
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
                                          ? AppTheme.black
                                          : AppTheme.grey600,
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
          color: selected ? AppTheme.black : AppTheme.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.black : AppTheme.grey200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.white : AppTheme.grey800,
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
        color: AppTheme.grey100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 14, color: AppTheme.grey600),
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

  const _HistoryListItem({
    required this.tx,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = tx.type == TransactionType.transfer
        ? '${tx.sourceWalletName ?? "Dompet"} ➔ ${tx.destinationWalletName ?? "Dompet"}'
        : (tx.categoryName ??
            (tx.type == TransactionType.income ? 'Pemasukan' : 'Pengeluaran'));

    final amountText = tx.type == TransactionType.income
        ? '+${CurrencyFormatter.format(tx.amount)}'
        : tx.type == TransactionType.expense
            ? '-${CurrencyFormatter.format(tx.amount)}'
            : CurrencyFormatter.format(tx.amount);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.grey200),
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
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppTheme.black),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
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
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.grey600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (tx.budgetName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.grey100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tx.budgetName!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.grey800,
                              ),
                            ),
                          ),
                        if (tx.note != null && tx.note!.isNotEmpty)
                          Text(
                            '• "${tx.note!}"',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.grey600,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          '• ${DateFormatter.formatTime(tx.occurredAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.grey600,
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
                      ? AppTheme.black
                      : tx.type == TransactionType.expense
                          ? AppTheme.grey800
                          : AppTheme.grey600,
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.grey600),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.grey600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.black,
              ),
            ),
          ),
        ],
      ),
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
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.grey100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilter ? Icons.search_off_rounded : Icons.receipt_long_outlined,
              size: 32,
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter
                ? 'Tidak ada transaksi ditemukan'
                : 'Belum ada riwayat transaksi',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter
                ? 'Coba sesuaikan kata kunci atau bersihkan filter yang aktif.'
                : 'Catat pemasukan, pengeluaran, atau transfer untuk melihat riwayat di sini.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.grey600,
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onResetFilter,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.black,
                side: const BorderSide(color: AppTheme.black),
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
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
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                color: AppTheme.grey200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filter Transaksi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.black,
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
                child: const Text(
                  'Reset',
                  style: TextStyle(color: AppTheme.grey600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Rentang Waktu
          const Text(
            'Rentang Tanggal',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.black,
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
          const Text(
            'Jenis Transaksi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.black,
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
          const Text(
            'Dompet',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.black,
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
              backgroundColor: AppTheme.black,
              foregroundColor: AppTheme.white,
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
          color: selected ? AppTheme.black : AppTheme.grey100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.white : AppTheme.black,
          ),
        ),
      ),
    );
  }
}
