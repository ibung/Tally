import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/budgets/presentation/providers/budget_providers.dart';
import 'package:tally/features/budgets/presentation/widgets/budget_form_sheet.dart';
import 'package:tally/shared/models/budget_model.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  bool _showInactive = false;
  BudgetPeriod? _periodFilter; // null = Semua

  void _showBudgetOptions(BuildContext context, DailyBudgetModel budget) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: AppTheme.border(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      budget.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBg(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      budget.period.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: AppTheme.textPrimary(context)),
              title: Text('Edit Kuota', style: TextStyle(color: AppTheme.textPrimary(context))),
              onTap: () {
                Navigator.pop(ctx);
                BudgetFormSheet.show(context, budget: budget);
              },
            ),
            ListTile(
              leading: Icon(
                budget.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                color: AppTheme.textPrimary(context),
              ),
              title: Text(
                budget.isActive ? 'Nonaktifkan Kuota' : 'Aktifkan Kembali',
                style: TextStyle(color: AppTheme.textPrimary(context)),
              ),
              subtitle: Text(
                budget.isActive
                    ? 'Sembunyikan dari pilihan saat mencatat transaksi'
                    : 'Gunakan kembali kuota ini untuk pengeluaran',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await ref
                    .read(budgetsProvider.notifier)
                    .toggleActive(budget.id, !budget.isActive);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppTheme.textPrimary(context)),
              title: Text('Hapus Kuota', style: TextStyle(color: AppTheme.textPrimary(context))),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, budget);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, DailyBudgetModel budget) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg(context),
        title: Text(
          'Hapus Kuota?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context)),
        ),
        content: Text(
          'Yakin ingin menghapus kuota "${budget.name}" (${budget.period.label})? Riwayat transaksi lama yang pernah menggunakan kuota ini akan tetap tersimpan.',
          style: TextStyle(color: AppTheme.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary(context)),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error(context),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(budgetsProvider.notifier).deleteBudget(budget.id);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  String _formatBudgetPeriodRange(DailyBudgetModel budget) {
    final start = DateTime.tryParse(budget.startDate);
    final end = budget.endDate != null ? DateTime.tryParse(budget.endDate!) : null;

    if (budget.isDaily) {
      if (start != null) {
        return 'Harian • ${DateFormatter.formatDate(start)}';
      }
      return 'Harian';
    }

    if (start != null && end != null) {
      return '${DateFormatter.formatDate(start)} - ${DateFormatter.formatDate(end)}';
    } else if (start != null) {
      return 'Mulai ${DateFormatter.formatDate(start)}';
    }
    return budget.period.label;
  }

  String? _getRemainingDaysBadge(DailyBudgetModel budget) {
    if (budget.endDate == null) return null;
    final end = DateTime.tryParse(budget.endDate!);
    if (end == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(end.year, end.month, end.day);
    final diff = target.difference(today).inDays;

    if (diff < 0) return 'Berakhir';
    if (diff == 0) return 'Hari Terakhir';
    return '$diff hari lagi';
  }

  IconData _getPeriodIcon(BudgetPeriod period) {
    switch (period) {
      case BudgetPeriod.daily:
        return Icons.today_rounded;
      case BudgetPeriod.weekly:
        return Icons.date_range_rounded;
      case BudgetPeriod.monthly:
        return Icons.calendar_month_rounded;
      case BudgetPeriod.custom:
        return Icons.all_inclusive_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: RefreshIndicator(
        color: AppTheme.textPrimary(context),
        backgroundColor: AppTheme.cardBg(context),
        onRefresh: () => ref.read(budgetsProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dynamic Summary Card
                    budgetsAsync.maybeWhen(
                      data: (allBudgets) {
                        final activeList = allBudgets.where((b) {
                          if (!b.isActive) return false;
                          if (_periodFilter != null && b.period != _periodFilter) return false;
                          return true;
                        }).toList();

                        final totalLimit = activeList.fold<int>(0, (s, b) => s + b.dailyLimit);
                        final totalSpent = activeList.fold<int>(0, (s, b) => s + b.spent);
                        final remaining = totalLimit - totalSpent;
                        final progress = totalLimit > 0
                            ? (totalSpent / totalLimit).clamp(0.0, 1.0)
                            : 0.0;

                        String headerTitle;
                        if (_periodFilter == BudgetPeriod.daily) {
                          headerTitle = 'Total Kuota Harian Hari Ini';
                        } else if (_periodFilter == BudgetPeriod.weekly) {
                          headerTitle = 'Total Kuota Mingguan Aktif';
                        } else if (_periodFilter == BudgetPeriod.monthly) {
                          headerTitle = 'Total Kuota Bulanan Aktif';
                        } else if (_periodFilter == BudgetPeriod.custom) {
                          headerTitle = 'Total Kuota Bebas Aktif';
                        } else {
                          headerTitle = 'Total Kuota & Tabungan/Sisa';
                        }

                        return Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg(context),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.borderStrong(context), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.isDark(context)
                                    ? const Color(0x20000000)
                                    : const Color(0x08000000),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.pie_chart_outline_rounded,
                                    size: 18,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    headerTitle,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary(context),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                CurrencyFormatter.format(totalLimit),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary(context),
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: AppTheme.border(context),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.textPrimary(context),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Sub info terpakai & sisa
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Terpakai: ${CurrencyFormatter.format(totalSpent)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    remaining >= 0
                                        ? 'Tabungan/Sisa: ${CurrencyFormatter.format(remaining)}'
                                        : 'Defisit: ${CurrencyFormatter.format(remaining.abs())}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary(context),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.savings_outlined,
                                    size: 13,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Kelebihan kuota diambil dari Tabungan/Sisa • Reset 1 bulan sekali',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 20),

                    // Period Filter Pills (Semua | Harian | Mingguan | Bulanan)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Semua',
                            selected: _periodFilter == null,
                            onTap: () => setState(() => _periodFilter = null),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Harian',
                            selected: _periodFilter == BudgetPeriod.daily,
                            onTap: () => setState(() => _periodFilter = BudgetPeriod.daily),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Mingguan',
                            selected: _periodFilter == BudgetPeriod.weekly,
                            onTap: () => setState(() => _periodFilter = BudgetPeriod.weekly),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Bulanan',
                            selected: _periodFilter == BudgetPeriod.monthly,
                            onTap: () => setState(() => _periodFilter = BudgetPeriod.monthly),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Bebas',
                            selected: _periodFilter == BudgetPeriod.custom,
                            onTap: () => setState(() => _periodFilter = BudgetPeriod.custom),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Controls Header: Tab Aktif/Nonaktif & Tambah Kuota
                    Row(
                      children: [
                        // Toggle Filter Aktif / Nonaktif
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppTheme.chipBg(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'Aktif',
                                selected: !_showInactive,
                                onTap: () => setState(() => _showInactive = false),
                              ),
                              _FilterChip(
                                label: 'Nonaktif',
                                selected: _showInactive,
                                onTap: () => setState(() => _showInactive = true),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),

                        // Tombol Tambah Kuota
                        InkWell(
                          onTap: () => BudgetFormSheet.show(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryButtonBg(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 16,
                                  color: AppTheme.primaryButtonText(context),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tambah Kuota',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryButtonText(context),
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

            // List Kuota
            budgetsAsync.when(
              loading: () => SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.textPrimary(context),
                    strokeWidth: 2,
                  ),
                ),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Gagal memuat kuota: $err',
                    style: TextStyle(color: AppTheme.textSecondary(context)),
                  ),
                ),
              ),
              data: (budgets) {
                final filtered = budgets.where((b) {
                  if (b.isActive == _showInactive) return false;
                  if (_periodFilter != null && b.period != _periodFilter) return false;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  String emptyTitle;
                  String emptySubtitle;

                  if (_showInactive) {
                    emptyTitle = 'Tidak ada kuota nonaktif';
                    emptySubtitle = 'Kuota yang dinonaktifkan akan muncul di sini';
                  } else {
                    if (_periodFilter == BudgetPeriod.weekly) {
                      emptyTitle = 'Belum ada kuota mingguan';
                      emptySubtitle = 'Buat kuota mingguan untuk mengatur belanja 7 hari ke depan';
                    } else if (_periodFilter == BudgetPeriod.monthly) {
                      emptyTitle = 'Belum ada kuota bulanan';
                      emptySubtitle = 'Buat kuota bulanan untuk membatasi pengeluaran per bulan berjalan';
                    } else if (_periodFilter == BudgetPeriod.daily) {
                      emptyTitle = 'Belum ada kuota harian';
                      emptySubtitle = 'Buat batas kuota harian untuk membatasi pengeluaran per hari';
                    } else {
                      emptyTitle = 'Belum ada kuota belanja';
                      emptySubtitle = 'Tambah kuota Harian, Mingguan, atau Bulanan untuk mengontrol pengeluaran';
                    }
                  }

                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showInactive
                                  ? Icons.pause_circle_outline
                                  : Icons.pie_chart_outline_rounded,
                              size: 48,
                              color: AppTheme.textMuted(context),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              emptyTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              emptySubtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final budget = filtered[index];
                        final remainingBadge = _getRemainingDaysBadge(budget);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: budget.isOverBudget
                                  ? AppTheme.borderStrong(context)
                                  : AppTheme.border(context),
                              width: budget.isOverBudget ? 1.5 : 1.0,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _showBudgetOptions(context, budget),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Icon Periode
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppTheme.chipBg(context),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          _getPeriodIcon(budget.period),
                                          color: AppTheme.textPrimary(context),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Nama Kuota & Rate
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              budget.name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textPrimary(context),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Text(
                                                  '${CurrencyFormatter.format(budget.dailyLimit)} ${budget.period.rateLabel}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.textSecondary(context),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.subtleBg(context),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: AppTheme.border(context),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    budget.period.label,
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppTheme.textSecondary(context),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Over-Budget Warning / Remaining Days Badge
                                      if (budget.isOverBudget)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.borderStrong(context),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'DITUTUP TABUNGAN',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.primaryButtonText(context),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        )
                                      else if (remainingBadge != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.subtleBg(context),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.border(context)),
                                          ),
                                          child: Text(
                                            remainingBadge,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textSecondary(context),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.more_vert_rounded,
                                        size: 18,
                                        color: AppTheme.textMuted(context),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Rentang Tanggal Subtitle
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 13,
                                        color: AppTheme.textSecondary(context),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _formatBudgetPeriodRange(budget),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary(context),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Progress Bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: budget.percentage,
                                      minHeight: 5,
                                      backgroundColor: AppTheme.border(context),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Detail Terpakai & Sisa
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Terpakai: ${CurrencyFormatter.format(budget.spent)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary(context),
                                        ),
                                      ),
                                      Text(
                                        budget.remaining >= 0
                                            ? 'Sisa: ${CurrencyFormatter.format(budget.remaining)}'
                                            : 'Ambil Tabungan: ${CurrencyFormatter.format(budget.remaining.abs())}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary(context),
                                        ),
                                      ),
                                    ],
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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.cardBg(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? AppTheme.textPrimary(context) : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
