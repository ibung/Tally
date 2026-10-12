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
              child: Text(
                budget.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary(context),
                ),
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
          'Yakin ingin menghapus kuota "${budget.name}"? Riwayat transaksi lama yang pernah menggunakan kuota ini akan tetap tersimpan.',
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
              backgroundColor: AppTheme.primaryButtonBg(context),
              foregroundColor: AppTheme.primaryButtonText(context),
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

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final summary = ref.watch(dailyBudgetSummaryProvider);

    final globalProgress = summary.totalLimit > 0
        ? (summary.totalSpent / summary.totalLimit).clamp(0.0, 1.0)
        : 0.0;

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
                    // Header Total Kuota Hero Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderStrong(context), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.isDark(context) ? const Color(0x20000000) : const Color(0x08000000),
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
                                'Total Kuota Belanja Hari Ini',
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
                            CurrencyFormatter.format(summary.totalLimit),
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
                              value: globalProgress,
                              minHeight: 6,
                              backgroundColor: AppTheme.border(context),
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textPrimary(context)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Sub info terpakai & sisa
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Terpakai: ${CurrencyFormatter.format(summary.totalSpent)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                summary.remaining >= 0
                                    ? 'Sisa: ${CurrencyFormatter.format(summary.remaining)}'
                                    : 'Lebih: ${CurrencyFormatter.format(summary.remaining.abs())}',
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
                    const SizedBox(height: 24),

                    // Controls Header: Tab Aktif/Nonaktif & Tambah Kuota
                    Row(
                      children: [
                        // Toggle Filter
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
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryButtonBg(context),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.add_rounded, size: 16, color: AppTheme.primaryButtonText(context)),
                                const SizedBox(width: 6),
                                Text(
                                  'Tambah',
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
                final filtered = budgets
                    .where((b) => b.isActive != _showInactive)
                    .toList();

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
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
                            _showInactive
                                ? 'Tidak ada kuota nonaktif'
                                : 'Belum ada kuota harian',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _showInactive
                                ? 'Kuota yang dinonaktifkan akan muncul di sini'
                                : 'Buat batas kuota harian (misal: Makan Rp50.000) untuk membatasi pengeluaran',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted(context),
                            ),
                            textAlign: TextAlign.center,
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
                        final budget = filtered[index];

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
                                      // Icon
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppTheme.chipBg(context),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.donut_small_rounded,
                                          color: AppTheme.textPrimary(context),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Nama Kuota & Limit
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
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${CurrencyFormatter.format(budget.dailyLimit)} / hari',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary(context),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Over-Budget Warning Badge
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
                                            'LEBIH KUOTA',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.primaryButtonText(context),
                                              letterSpacing: 0.5,
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
                                  const SizedBox(height: 14),

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
                                            : 'Over: ${CurrencyFormatter.format(budget.remaining.abs())}',
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
                    color: AppTheme.isDark(context) ? const Color(0x30000000) : const Color(0x0A000000),
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
