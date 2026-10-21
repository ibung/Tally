import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/categories/presentation/helpers/category_icon_helper.dart';
import 'package:tally/features/categories/presentation/helpers/chart_palette.dart';
import 'package:tally/shared/models/category_model.dart';

class CategoryBarChart extends StatelessWidget {
  final List<CategoryChartItem> items;
  final double animationProgress;
  final CategoryType type;

  const CategoryBarChart({
    super.key,
    required this.items,
    required this.animationProgress,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final totalAmount = items.fold<int>(0, (s, it) => s + it.totalAmount);
    final maxAmount = items.isNotEmpty ? items.first.totalAmount : 1;
    final topCategory = items.isNotEmpty ? items.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.darkBorderStrong : AppTheme.border(context),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0x20000000) : const Color(0x06000000),
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
                  Text(
                    type == CategoryType.expense
                        ? 'Total Pengeluaran'
                        : 'Total Pemasukan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.subtleBg(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${items.length} Kategori',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                CurrencyFormatter.format(totalAmount),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary(context),
                  letterSpacing: -0.5,
                ),
              ),
              if (topCategory != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ChartPalette.getColor(0, isDark).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: ChartPalette.getColor(0, isDark),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Terbesar: ${topCategory.categoryName} (${(topCategory.percentage * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: ChartPalette.getColor(0, isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Peringkat Kategori',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
            Text(
              'Urut berdasarkan nominal',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Ranked Category Bars
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            final color = ChartPalette.getColor(index, isDark);
            final ratio = maxAmount > 0 ? (item.totalAmount / maxAmount) : 0.0;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Rank Badge
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: index < 3
                              ? color.withValues(alpha: 0.15)
                              : AppTheme.subtleBg(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '#${index + 1}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: index < 3 ? color : AppTheme.textSecondary(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Category Icon
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          CategoryIconHelper.getIcon(item.categoryIcon),
                          size: 17,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Name & Count
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.categoryName,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${item.transactionCount} transaksi',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Amount & Percentage
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(item.totalAmount),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${(item.percentage * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Animated Progress Bar Track
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final totalTrackWidth = constraints.maxWidth;
                      final barWidth = math.max(
                        0.0,
                        totalTrackWidth * ratio * animationProgress.clamp(0.0, 1.0),
                      );

                      return Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: barWidth,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
