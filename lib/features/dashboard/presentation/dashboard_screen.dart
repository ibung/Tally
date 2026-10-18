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
import 'package:tally/shared/widgets/transaction_detail_dialog.dart';
import 'package:tally/features/sync/presentation/providers/sync_providers.dart';
import 'package:tally/features/sync/presentation/widgets/sync_account_sheet.dart';

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

  void _showTransactionDetails(BuildContext context, TransactionModel tx) {
    showTransactionDetailDialog(context, tx, _getTransactionIcon(tx));
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
      backgroundColor: AppTheme.bg(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          TransactionFormSheet.show(context, date: selectedDate);
        },
        backgroundColor: AppTheme.primaryButtonBg(context),
        foregroundColor: AppTheme.primaryButtonText(context),
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
        color: AppTheme.textPrimary(context),
        backgroundColor: AppTheme.cardBg(context),
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
                    // Cloud Sync Banner (shown if not logged in)
                    Consumer(
                      builder: (context, ref, _) {
                        final userAsync = ref.watch(googleUserProvider);
                        final cachedUserAsync = ref.watch(cachedGoogleUserProvider);
                        final isLoggedIn = userAsync.valueOrNull != null || (cachedUserAsync.valueOrNull?['email'] != null);
                        if (isLoggedIn) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () async {
                              final syncNotifier = ref.read(syncProvider.notifier);
                              await syncNotifier.signIn();
                              if (context.mounted) {
                                SyncAccountSheet.show(context);
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.subtleBg(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.border(context)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.cloud_upload_outlined, size: 20, color: AppTheme.textPrimary(context)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cadangkan ke Google Drive',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary(context),
                                          ),
                                        ),
                                        Text(
                                          'Amankan data keuangan Anda agar tidak hilang',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textSecondary(context)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

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
                            Text(
                              'Transaksi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            transactionsAsync.maybeWhen(
                              data: (list) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.chipBg(context),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${list.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                ),
                              ),
                              orElse: () => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                        Text(
                          DateFormatter.formatRelative(selectedDate),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary(context),
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
                  padding: const EdgeInsets.symmetric(vertical: 30),
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
    final isSpecialRelative = relativeLabel == 'Hari ini' ||
        relativeLabel == 'Kemarin' ||
        relativeLabel == 'Besok';
    final displayText = isSpecialRelative ? '$relativeLabel • $fullDateLabel' : fullDateLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          // Previous day button
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
            color: AppTheme.textPrimary(context),
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
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: AppTheme.textSecondary(context),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        displayText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary(context),
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
            color: AppTheme.textPrimary(context),
            tooltip: 'Hari Berikutnya',
            splashRadius: 20,
          ),

          // Return to today shortcut pill if not today
          if (!isToday) ...[
            Container(
              height: 24,
              width: 1,
              color: AppTheme.border(context),
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            InkWell(
              onTap: onJumpToday,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.chipBg(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.today_rounded, size: 14, color: AppTheme.textPrimary(context)),
                    const SizedBox(width: 4),
                    Text(
                      'Hari Ini',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary(context),
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
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderStrong(context), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.isDark(context) ? const Color(0x20000000) : const Color(0x06000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 16,
                    color: AppTheme.textSecondary(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Saldo Akhir Historis',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary(context),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.chipBg(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormatter.formatDate(selectedDate),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          balanceAsync.when(
            loading: () => Text(
              'Memuat...',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary(context),
              ),
            ),
            error: (_, __) => Text(
              'Rp -',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary(context),
              ),
            ),
            data: (balance) => Text(
              CurrencyFormatter.format(balance),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary(context),
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Posisi saldo seluruh dompet aktif di akhir tanggal ini',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary(context),
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
          color: AppTheme.chipBg(context),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        final net = summary.income - summary.expense;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border(context)),
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
                            color: AppTheme.chipBg(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            size: 16,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pemasukan',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '+${CurrencyFormatter.format(summary.income)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary(context),
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
                    color: AppTheme.border(context),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),

                  // Pengeluaran
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.chipBg(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 16,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pengeluaran',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '-${CurrencyFormatter.format(summary.expense)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary(context),
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
                Divider(color: AppTheme.border(context), height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Arus Kas Bersih',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary(context),
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
                        color: AppTheme.textPrimary(context),
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
  final ({
    int totalLimit,
    int totalSpent,
    int remaining,
    int tabunganSisa,
    int deficitsCovered,
    bool hasDeficitCovered,
  }) budgetSummary;

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
          color: AppTheme.chipBg(context),
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
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 20,
                  color: AppTheme.textSecondary(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Belum ada kuota aktif',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/budgets'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary(context),
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
              color: AppTheme.cardBg(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isOver ? AppTheme.borderStrong(context) : AppTheme.border(context),
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
                        Icon(
                          Icons.pie_chart_outline_rounded,
                          size: 16,
                          color: AppTheme.textPrimary(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Kuota',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.chipBg(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${activeBudgets.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Lihat Semua',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppTheme.textSecondary(context),
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
                    backgroundColor: AppTheme.border(context),
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textPrimary(context)),
                  ),
                ),
                const SizedBox(height: 10),

                // Sub Info: Terpakai vs Tabungan/Sisa
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Terpakai: ${CurrencyFormatter.format(totalSpent)} / ${CurrencyFormatter.format(totalLimit)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      !isOver
                          ? 'Tabungan/Sisa: ${CurrencyFormatter.format(remaining)}'
                          : 'Defisit: ${CurrencyFormatter.format(remaining.abs())}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ],
                ),

                // Notice when deficit is covered from Tabungan/Sisa
                if (budgetSummary.hasDeficitCovered && !isOver) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBg(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.savings_outlined,
                          size: 14,
                          color: AppTheme.textPrimary(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Kelebihan kuota ${CurrencyFormatter.format(budgetSummary.deficitsCovered)} ditutup dari Tabungan/Sisa',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Over-budget notice if collective Tabungan/Sisa exhausted
                if (isOver) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBg(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: AppTheme.textPrimary(context),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pengeluaran melebihi total kuota & Tabungan/Sisa sebesar ${CurrencyFormatter.format(remaining.abs())}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary(context),
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
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.chipBg(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 32,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada transaksi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada catatan keuangan pada ${DateFormatter.formatDate(selectedDate)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onAddTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary(context),
              side: BorderSide(color: AppTheme.borderStrong(context)),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border(context)),
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
                  color: AppTheme.chipBg(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppTheme.textPrimary(context),
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary(context),
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
                        if (tx.isEdited)
                          Text(
                            '• diedit ${DateFormatter.formatTime(tx.updatedAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppTheme.textSecondary(context),
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
  }
}

