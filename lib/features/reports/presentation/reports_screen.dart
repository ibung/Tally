import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:tally/core/services/report_pdf_service.dart';
import 'package:tally/core/theme/app_theme.dart';
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/features/reports/presentation/providers/report_providers.dart';
import 'package:tally/shared/models/report_model.dart';

enum _PeriodPreset {
  thisMonth('Bulan Ini'),
  lastMonth('Bulan Lalu'),
  last3Months('3 Bulan'),
  thisYear('Tahun Ini'),
  custom('Pilih Tanggal');

  final String label;
  const _PeriodPreset(this.label);
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _PeriodPreset _preset = _PeriodPreset.thisMonth;
  bool _includeDetails = true;

  Future<void> _selectPreset(_PeriodPreset preset) async {
    final now = DateTime.now();
    final ReportPeriod? period = switch (preset) {
      _PeriodPreset.thisMonth => ReportPeriod.thisMonth(now),
      _PeriodPreset.lastMonth => ReportPeriod.lastMonth(now),
      _PeriodPreset.last3Months => ReportPeriod.last3Months(now),
      _PeriodPreset.thisYear => ReportPeriod.thisYear(now),
      _PeriodPreset.custom => await _pickCustomPeriod(),
    };
    if (period == null || !mounted) return;
    setState(() => _preset = preset);
    ref.read(reportPeriodProvider.notifier).state = period;
  }

  Future<ReportPeriod?> _pickCustomPeriod() async {
    final current = ref.read(reportPeriodProvider);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: current.start, end: current.end),
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
    if (picked == null) return null;
    return ReportPeriod(start: picked.start, end: picked.end);
  }

  void _openPdf(ReportData data) {
    HapticFeedback.lightImpact();
    final includeDetails = _includeDetails;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _ReportPreviewScreen(
          data: data,
          includeDetails: includeDetails,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(reportPeriodProvider);
    final dataAsync = ref.watch(reportDataProvider);
    final data = dataAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: _reportAppBar(context, 'Laporan'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _PeriodPreset.values)
                _PeriodChip(
                  label: preset.label,
                  selected: preset == _preset,
                  onTap: () => _selectPreset(preset),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            period.label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          dataAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => const _Message(
              icon: Icons.error_outline_rounded,
              text: 'Laporan gagal dimuat. Coba buka kembali halaman ini.',
            ),
            data: (data) => data.isEmpty
                ? const _Message(
                    icon: Icons.receipt_long_outlined,
                    text:
                        'Belum ada pemasukan atau pengeluaran pada periode ini.',
                  )
                : _ReportSummary(data: data),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _includeDetails,
                onChanged: (v) => setState(() => _includeDetails = v),
                title: Text(
                  'Sertakan rincian transaksi',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: data == null || data.isEmpty
                      ? null
                      : () => _openPdf(data),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Buat PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

AppBar _reportAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: AppTheme.bg(context),
    elevation: 0,
    scrolledUnderElevation: 0,
    title: Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary(context),
      ),
    ),
    iconTheme: IconThemeData(color: AppTheme.textPrimary(context)),
  );
}

class _ReportPreviewScreen extends StatelessWidget {
  final ReportData data;
  final bool includeDetails;

  const _ReportPreviewScreen(
      {required this.data, required this.includeDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: _reportAppBar(context, 'Pratinjau Laporan'),
      body: PdfPreview(
        build: (_) =>
            ReportPdfService.generate(data, includeDetails: includeDetails),
        pdfFileName: ReportPdfService.fileName(data.period),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        loadingWidget: const CircularProgressIndicator(),
        onError: (context, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('PDF gagal dibuat. Silakan coba lagi.'),
          ),
        ),
        scrollViewDecoration: BoxDecoration(color: AppTheme.subtleBg(context)),
        actionBarTheme: PdfActionBarTheme(
          backgroundColor: AppTheme.cardBg(context),
          iconColor: AppTheme.textPrimary(context),
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected ? AppTheme.bg(context) : AppTheme.textPrimary(context),
      ),
      backgroundColor: AppTheme.cardBg(context),
      selectedColor: AppTheme.textPrimary(context),
      side: BorderSide(color: AppTheme.border(context)),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  final ReportData data;

  const _ReportSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    final lines = data.expenseCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryRow(
          label: 'Pengeluaran',
          value: CurrencyFormatter.format(data.totalExpense),
          emphasized: true,
        ),
        _SummaryRow(
          label: 'Pemasukan',
          value: CurrencyFormatter.format(data.totalIncome),
        ),
        _SummaryRow(
          label: 'Selisih',
          value: data.net < 0
              ? '−${CurrencyFormatter.format(-data.net)}'
              : CurrencyFormatter.format(data.net),
        ),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Pengeluaran per Kategori',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          for (final line in lines)
            _CategoryRow(line: line, largest: lines.first.total),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: emphasized ? 20 : 15,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final ReportLine line;
  final int largest;

  const _CategoryRow({required this.line, required this.largest});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${CurrencyFormatter.format(line.total)} · '
                '${(line.share * 100).round()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: largest > 0 ? line.total / largest : 0,
              minHeight: 4,
              backgroundColor: AppTheme.subtleBg(context),
              valueColor: AlwaysStoppedAnimation(AppTheme.textPrimary(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppTheme.textSecondary(context)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
