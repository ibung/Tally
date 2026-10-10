import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/budgets/presentation/providers/budget_providers.dart';
import 'package:tally/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:tally/features/transactions/presentation/widgets/transaction_form_sheet.dart';
import 'package:tally/shared/models/budget_model.dart';
import 'package:tally/shared/models/transaction_model.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _setDate(DateTime newDate) {
    ref.read(selectedTransactionDateProvider.notifier).state = newDate;
    ref.read(selectedDateForBudgetsProvider.notifier).state = newDate;
  }

  void _previousDay() {
    final current = ref.read(selectedTransactionDateProvider);
    _setDate(current.subtract(const Duration(days: 1)));
  }

  void _nextDay() {
    final current = ref.read(selectedTransactionDateProvider);
    _setDate(current.add(const Duration(days: 1)));
  }

  void _jumpToToday() {
    _setDate(DateTime.now());
  }

  Future<void> _pickDate() async {
    final current = ref.read(selectedTransactionDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
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
      _setDate(picked);
    }
  }

  Future<void> _refresh() async {
    await ref.read(transactionsProvider.notifier).refresh();
    await ref.read(budgetsProvider.notifier).refresh();
    ref.invalidate(historicalEndBalanceProvider);
    ref.invalidate(dailySummaryProvider);
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

            // Header Jenis & Nominal
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
            _DetailItem(
              icon: Icons.calendar_today_outlined,
              label: 'Waktu',
              value: DateFormatter.formatDateTime(tx.occurredAt),
            ),

            if (tx.type == TransactionType.transfer) ...[
              _DetailItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Dompet Asal',
                value: tx.sourceWalletName ?? '-',
              ),
              _DetailItem(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Dompet Tujuan',
                value: tx.destinationWalletName ?? '-',
              ),
            ] else ...[
              _DetailItem(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Dompet',
                value: tx.walletName ?? '-',
              ),
            ],

            if (tx.categoryName != null)
              _DetailItem(
                icon: Icons.category_outlined,
                label: 'Kategori',
                value: tx.categoryName!,
              ),

            if (tx.budgetName != null)
              _DetailItem(
                icon: Icons.pie_chart_outline_rounded,
                label: 'Kuota Harian',
                value: tx.budgetName!,
              ),

            if (tx.note != null && tx.note!.isNotEmpty)
              _DetailItem(
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
    final selectedDate = ref.watch(selectedTransactionDateProvider);
    final isToday = _isSameDay(selectedDate, DateTime.now());

    final historicalBalanceAsync = ref.watch(historicalEndBalanceProvider);
    final dailySummaryAsync = ref.watch(dailySummaryProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final budgetSummary = ref.watch(dailyBudgetSummaryProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.white,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          TransactionFormSheet.show(context, date: selectedDate);
        },
        backgroundColor: AppTheme.black,
        foregroundColor: AppTheme.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Catat',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.black,
        backgroundColor: AppTheme.white,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Date Navigation Bar
                    _DateNavigator(
                      selectedDate: selectedDate,
                      isToday: isToday,
                      onPrevious: _previousDay,
                      onNext: _nextDay,
                      onPickDate: _pickDate,
                      onJumpToday: _jumpToToday,
                    ),
                    const SizedBox(height: 16),

                    // Card 1: Saldo Akhir Historis
                    _HistoricalBalanceCard(
                      selectedDate: selectedDate,
                      balanceAsync: historicalBalanceAsync,
                    ),
                    const SizedBox(height: 14),

                    // Card 2: Pemasukan & Pengeluaran Harian
                    _DailyCashFlowCard(
                      summaryAsync: dailySummaryAsync,
                    ),
                    const SizedBox(height: 14),

                    // Card 3: Ringkasan Kuota Harian
                    _DailyBudgetOverviewCard(
                      budgetsAsync: budgetsAsync,
                      budgetSummary: budgetSummary,
                    ),
                    const SizedBox(height: 24),

                    // Section 4: Header Daftar Transaksi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Transaksi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.black,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            transactionsAsync.maybeWhen(
                              data: (list) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.grey100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${list.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.grey800,
                                  ),
                                ),
                              ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        Text(
                          DateFormatter.formatRelative(selectedDate),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.grey600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // Transactions List Slivers
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
                  padding: const EdgeInsets.symmetric(vertical: 30),
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
                    child: _EmptyTransactionsState(
                      selectedDate: selectedDate,
                      onAddTap: () {
                        TransactionFormSheet.show(context, date: selectedDate);
                      },
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tx = transactions[index];
                        return _TransactionListItem(
                          tx: tx,
                          icon: _getTransactionIcon(tx),
                          onTap: () => _showTransactionDetails(context, tx),
                        );
                      },
                      childCount: transactions.length,
                    ),
                  ),
                );
              },
            ),

            // Bottom spacing to avoid FAB overlay
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
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

class _DateNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;
  final VoidCallback onJumpToday;

  const _DateNavigator({
    required this.selectedDate,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
    required this.onJumpToday,
  });

  @override
  Widget build(BuildContext context) {
    final relativeLabel = DateFormatter.formatRelative(selectedDate);
    final fullDateLabel = DateFormatter.formatDate(selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Row(
        children: [
          // Previous day button
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
            color: AppTheme.black,
            tooltip: 'Hari Sebelumnya',
            splashRadius: 20,
          ),

          // Date Selector Clickable Center
          Expanded(
            child: InkWell(
              onTap: onPickDate,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: AppTheme.grey600,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$relativeLabel • $fullDateLabel',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Next day button
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded, size: 24),
            color: AppTheme.black,
            tooltip: 'Hari Berikutnya',
            splashRadius: 20,
          ),

          // Return to today shortcut pill if not today
          if (!isToday) ...[
            Container(
              height: 24,
              width: 1,
              color: AppTheme.grey200,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            InkWell(
              onTap: onJumpToday,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.today_rounded, size: 14, color: AppTheme.black),
                    SizedBox(width: 4),
                    Text(
                      'Hari Ini',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _HistoricalBalanceCard extends StatelessWidget {
  final DateTime selectedDate;
  final AsyncValue<int> balanceAsync;

  const _HistoricalBalanceCard({
    required this.selectedDate,
    required this.balanceAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.black, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 16,
                    color: AppTheme.grey600,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Saldo Akhir Historis',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.grey600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormatter.formatDate(selectedDate),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.grey800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          balanceAsync.when(
            loading: () => const Text(
              'Memuat...',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.black,
              ),
            ),
            error: (_, __) => const Text(
              'Rp -',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.black,
              ),
            ),
            data: (balance) => Text(
              CurrencyFormatter.format(balance),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.black,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Posisi saldo seluruh dompet aktif di akhir tanggal ini',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.grey600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCashFlowCard extends StatelessWidget {
  final AsyncValue<({int income, int expense})> summaryAsync;

  const _DailyCashFlowCard({required this.summaryAsync});

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      loading: () => Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        final net = summary.income - summary.expense;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.grey200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Pemasukan
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.grey100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            size: 16,
                            color: AppTheme.black,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pemasukan',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.grey600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '+${CurrencyFormatter.format(summary.income)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    height: 36,
                    width: 1,
                    color: AppTheme.grey200,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),

                  // Pengeluaran
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.grey100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            size: 16,
                            color: AppTheme.grey800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pengeluaran',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.grey600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '-${CurrencyFormatter.format(summary.expense)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.grey800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (summary.income > 0 || summary.expense > 0) ...[
                const SizedBox(height: 12),
                const Divider(color: AppTheme.grey200, height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Arus Kas Bersih',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      net >= 0
                          ? '+${CurrencyFormatter.format(net)}'
                          : '-${CurrencyFormatter.format(net.abs())}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: net >= 0 ? AppTheme.black : AppTheme.grey800,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DailyBudgetOverviewCard extends StatelessWidget {
  final AsyncValue<List<DailyBudgetModel>> budgetsAsync;
  final ({int totalLimit, int totalSpent, int remaining}) budgetSummary;

  const _DailyBudgetOverviewCard({
    required this.budgetsAsync,
    required this.budgetSummary,
  });

  @override
  Widget build(BuildContext context) {
    return budgetsAsync.when(
      loading: () => Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (budgets) {
        final activeBudgets = budgets.where((b) => b.isActive).toList();

        if (activeBudgets.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 20,
                  color: AppTheme.grey600,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Belum ada kuota harian aktif',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.grey600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/budgets'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  child: const Text(
                    'Atur Kuota',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        }

        final totalLimit = budgetSummary.totalLimit;
        final totalSpent = budgetSummary.totalSpent;
        final remaining = budgetSummary.remaining;
        final progress = totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;
        final isOver = remaining < 0;

        return InkWell(
          onTap: () => context.go('/budgets'),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isOver ? AppTheme.black : AppTheme.grey200,
                width: isOver ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 16,
                          color: AppTheme.black,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Kuota Harian',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.black,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.grey100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${activeBudgets.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.grey800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Text(
                          'Lihat Semua',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.grey600,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppTheme.grey600,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppTheme.grey200,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.black),
                  ),
                ),
                const SizedBox(height: 10),

                // Sub Info: Terpakai vs Sisa
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Terpakai: ${CurrencyFormatter.format(totalSpent)} / ${CurrencyFormatter.format(totalLimit)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.grey600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      !isOver
                          ? 'Sisa: ${CurrencyFormatter.format(remaining)}'
                          : 'Lebih: ${CurrencyFormatter.format(remaining.abs())}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isOver ? AppTheme.black : AppTheme.grey800,
                      ),
                    ),
                  ],
                ),

                // Non-judgmental Over-budget notice (PRD Bab 4 & 7)
                if (isOver) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.grey100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: AppTheme.black,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pengeluaran hari ini melewati kuota sebesar ${CurrencyFormatter.format(remaining.abs())}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onAddTap;

  const _EmptyTransactionsState({
    required this.selectedDate,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.grey100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 32,
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada transaksi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada catatan keuangan pada ${DateFormatter.formatDate(selectedDate)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.grey600,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onAddTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.black,
              side: const BorderSide(color: AppTheme.black),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              'Catat Transaksi',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionListItem extends StatelessWidget {
  final TransactionModel tx;
  final IconData icon;
  final VoidCallback onTap;

  const _TransactionListItem({
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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.grey200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppTheme.black,
                ),
              ),
              const SizedBox(width: 14),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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

              // Amount
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
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

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
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
