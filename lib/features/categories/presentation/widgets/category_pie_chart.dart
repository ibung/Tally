import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/categories/presentation/helpers/category_icon_helper.dart';
import 'package:tally/features/categories/presentation/helpers/chart_palette.dart';
import 'package:tally/shared/models/category_model.dart';

class CategoryPieChart extends StatefulWidget {
  final List<CategoryChartItem> items;
  final double animationProgress;
  final CategoryType type;

  const CategoryPieChart({
    super.key,
    required this.items,
    required this.animationProgress,
    required this.type,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(CategoryPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type || oldWidget.items != widget.items) {
      _selectedIndex = null;
    }
  }

  void _onChartTap(Offset localPosition, Size size) {
    if (widget.items.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final outerRadius = (math.min(size.width, size.height) / 2) - 10;
    const strokeWidth = 26.0;
    final innerRadius = outerRadius - strokeWidth - 15;

    // Check if touch is within donut ring
    if (distance < innerRadius || distance > outerRadius + 15) {
      if (_selectedIndex != null) {
        setState(() => _selectedIndex = null);
      }
      return;
    }

    // Angle starting from 12 o'clock (-pi / 2)
    var touchAngle = math.atan2(dy, dx);
    touchAngle += math.pi / 2;
    if (touchAngle < 0) {
      touchAngle += 2 * math.pi;
    }

    // Match angle with slice
    var accumulated = 0.0;
    int? foundIndex;
    for (var i = 0; i < widget.items.length; i++) {
      final sweep = widget.items[i].percentage * 2 * math.pi;
      if (touchAngle >= accumulated && touchAngle <= accumulated + sweep) {
        foundIndex = i;
        break;
      }
      accumulated += sweep;
    }

    setState(() {
      if (_selectedIndex == foundIndex) {
        _selectedIndex = null;
      } else {
        _selectedIndex = foundIndex;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final totalAmount = widget.items.fold<int>(0, (s, it) => s + it.totalAmount);

    CategoryChartItem? selectedItem;
    if (_selectedIndex != null && _selectedIndex! < widget.items.length) {
      selectedItem = widget.items[_selectedIndex!];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Donut Chart Canvas Container
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg(context),
            borderRadius: BorderRadius.circular(20),
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
          child: Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chartSize = Size(constraints.maxWidth, constraints.maxHeight);
                  return GestureDetector(
                    onTapUp: (details) => _onChartTap(details.localPosition, chartSize),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Custom Paint Donut
                        CustomPaint(
                          size: chartSize,
                          painter: _PieChartPainter(
                            items: widget.items,
                            animationProgress: widget.animationProgress,
                            selectedIndex: _selectedIndex,
                            isDark: isDark,
                          ),
                        ),

                        // Center Info Text
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selectedItem != null) ...[
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: ChartPalette.getColor(_selectedIndex!, isDark)
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CategoryIconHelper.getIcon(selectedItem.categoryIcon),
                                    size: 16,
                                    color: ChartPalette.getColor(_selectedIndex!, isDark),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  selectedItem.categoryName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.format(selectedItem.totalAmount),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: ChartPalette.getColor(_selectedIndex!, isDark),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${(selectedItem.percentage * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  widget.type == CategoryType.expense
                                      ? 'Total Pengeluaran'
                                      : 'Total Pemasukan',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.format(totalAmount),
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary(context),
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.items.length} Kategori',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary(context),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Breakdown Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Rincian Berdasarkan Kategori',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary(context),
              ),
            ),
            Text(
              '${widget.items.length} Kategori',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Category Breakdown List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final color = ChartPalette.getColor(index, isDark);
            final isSelected = _selectedIndex == index;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedIndex = isSelected ? null : index;
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: isDark ? 0.15 : 0.08)
                      : AppTheme.cardBg(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : AppTheme.border(context),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    // Color bar indicator
                    Container(
                      width: 4,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Icon Container
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        CategoryIconHelper.getIcon(item.categoryIcon),
                        size: 18,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name & Transaction Count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.categoryName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
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

                    // Amount & Percentage Pill
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
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(item.percentage * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<CategoryChartItem> items;
  final double animationProgress;
  final int? selectedIndex;
  final bool isDark;

  _PieChartPainter({
    required this.items,
    required this.animationProgress,
    required this.selectedIndex,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (math.min(size.width, size.height) / 2) - 12;
    const baseStrokeWidth = 26.0;

    var startAngle = -math.pi / 2;
    final gap = items.length > 1 ? 0.04 : 0.0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final fullSweep = item.percentage * 2 * math.pi;
      final sweepAngle = (fullSweep - gap) * animationProgress;

      if (sweepAngle > 0) {
        final isSelected = selectedIndex == i;
        final radius = isSelected ? baseRadius + 4 : baseRadius;
        final strokeWidth = isSelected ? baseStrokeWidth + 4 : baseStrokeWidth;
        final color = ChartPalette.getColor(i, isDark);

        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = color;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle + (gap / 2),
          sweepAngle,
          false,
          paint,
        );
      }

      startAngle += fullSweep * animationProgress;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.items != items ||
        oldDelegate.isDark != isDark;
  }
}
