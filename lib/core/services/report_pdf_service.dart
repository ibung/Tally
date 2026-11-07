import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tally/core/utils/formatters.dart';
import 'package:tally/shared/models/report_model.dart';
import 'package:tally/shared/models/transaction_model.dart';

/// Membuat dokumen PDF laporan keuangan.
///
/// Font dibundel di aset agar laporan tetap bisa dibuat tanpa internet.
class ReportPdfService {
  ReportPdfService._();

  static const _regularFontAsset = 'assets/fonts/Roboto-Regular.ttf';
  static const _boldFontAsset = 'assets/fonts/Roboto-Bold.ttf';

  static String fileName(ReportPeriod period) =>
      'Laporan-Tally-${period.startKey}_${period.endKey}.pdf';

  /// Berjalan di isolate terpisah: laporan dengan ribuan transaksi tidak boleh
  /// membuat UI tersendat.
  static Future<Uint8List> generate(
    ReportData data, {
    required bool includeDetails,
  }) async {
    final regular = await rootBundle.load(_regularFontAsset);
    final bold = await rootBundle.load(_boldFontAsset);
    return compute(_generateInIsolate, (
      data: data,
      regular: regular,
      bold: bold,
      includeDetails: includeDetails,
    ));
  }

  static Future<Uint8List> _generateInIsolate(
    ({
      ReportData data,
      ByteData regular,
      ByteData bold,
      bool includeDetails,
    }) args,
  ) async {
    // Data locale per isolate; isolate ini belum melewati inisialisasi main().
    await initializeDateFormatting('id_ID');
    return build(
      args.data,
      regularFont: args.regular,
      boldFont: args.bold,
      includeDetails: args.includeDetails,
    );
  }

  @visibleForTesting
  static Future<Uint8List> build(
    ReportData data, {
    required ByteData regularFont,
    required ByteData boldFont,
    required bool includeDetails,
  }) {
    return _ReportDocument(
      data: data,
      regularFont: regularFont,
      boldFont: boldFont,
      includeDetails: includeDetails,
    ).save();
  }
}

class _ReportDocument {
  static const _ink = PdfColor.fromInt(0xFF0A0A0A);
  static const _secondary = PdfColor.fromInt(0xFF666666);
  static const _mutedBar = PdfColor.fromInt(0xFFAAAAAA);
  static const _rule = PdfColor.fromInt(0xFFE8E8E8);
  static const _tileBg = PdfColor.fromInt(0xFFF5F5F5);

  final ReportData data;
  final bool includeDetails;
  final pw.Font _regular;
  final pw.Font _bold;
  final Map<int, int> _glyphs;

  _ReportDocument({
    required this.data,
    required ByteData regularFont,
    required ByteData boldFont,
    required this.includeDetails,
  })  : _regular = pw.Font.ttf(regularFont),
        _bold = pw.Font.ttf(boldFont),
        _glyphs = TtfParser(regularFont).charToGlyphIndexMap;

  Future<Uint8List> save() {
    final doc = pw.Document(
      title: 'Laporan Keuangan Tally ${data.period.label}',
      author: 'Tally',
      creator: 'Tally',
    );
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 36),
          theme: pw.ThemeData.withFont(base: _regular, bold: _bold).copyWith(
            defaultTextStyle: pw.TextStyle(
              font: _regular,
              fontBold: _bold,
              fontSize: 9.5,
              color: _ink,
            ),
          ),
        ),
        // Bawaan paket hanya 20 halaman dan akan melempar exception setelahnya;
        // rincian setahun penuh bisa jauh lebih panjang.
        maxPages: 2000,
        footer: _footer,
        build: (_) => [
          _title(),
          pw.SizedBox(height: 18),
          _summaryTiles(),
          pw.SizedBox(height: 20),
          ..._highlights(),
          ..._expenseCategories(),
          ..._trend(),
          ..._incomeCategories(),
          ..._wallets(),
          if (includeDetails) ..._details(),
          pw.SizedBox(height: 16),
          pw.Text(
            'Transfer antar-dompet dan koreksi saldo tidak dihitung sebagai '
            'pemasukan maupun pengeluaran.',
            style: const pw.TextStyle(fontSize: 8, color: _secondary),
          ),
        ],
      ),
    );
    return doc.save();
  }

  // ---------------------------------------------------------------- Bagian

  pw.Widget _title() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Tally',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: _secondary,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Laporan Keuangan',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(data.period.label, style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 2),
        pw.Text(
          'Dibuat ${DateFormatter.formatDateTime(data.generatedAt)}',
          style: const pw.TextStyle(fontSize: 8.5, color: _secondary),
        ),
      ],
    );
  }

  pw.Widget _summaryTiles() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _tile(
              'Pengeluaran',
              CurrencyFormatter.format(data.totalExpense),
              _changeSentence(data.totalExpense, data.previousExpense),
            ),
            pw.SizedBox(width: 8),
            _tile(
              'Pemasukan',
              CurrencyFormatter.format(data.totalIncome),
              _changeSentence(data.totalIncome, data.previousIncome),
            ),
            pw.SizedBox(width: 8),
            _tile(
              'Selisih',
              _signedAmount(data.net),
              data.net >= 0
                  ? 'Pemasukan lebih besar'
                  : 'Pengeluaran lebih besar',
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Perubahan dibandingkan dengan ${data.previousPeriod.label}.',
          style: const pw.TextStyle(fontSize: 8, color: _secondary),
        ),
      ],
    );
  }

  pw.Widget _tile(String label, String value, String caption) {
    return pw.Expanded(
      child: pw.Container(
        height: 68,
        padding: const pw.EdgeInsets.all(10),
        decoration: const pw.BoxDecoration(
          color: _tileBg,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(color: _secondary)),
            pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              caption,
              style: const pw.TextStyle(fontSize: 8, color: _secondary),
            ),
          ],
        ),
      ),
    );
  }

  List<pw.Widget> _highlights() {
    if (data.totalExpense == 0) return const [];
    final top = data.expenseCategories.first;
    final largest = data.largestExpense!;
    final peak = data.peakExpenseDay!;
    final rate = data.savingsRate;
    final rows = <(String, String)>[
      (
        'Kategori terbesar',
        '${_safe(top.name)} · ${CurrencyFormatter.format(top.total)} '
            '(${_percent(top.share)} dari pengeluaran)',
      ),
      (
        'Rata-rata per hari',
        '${CurrencyFormatter.format(data.averageDailyExpense)} '
            'selama ${data.period.dayCount} hari',
      ),
      (
        'Hari paling boros',
        '${DateFormatter.formatFullDay(peak.date)} · '
            '${CurrencyFormatter.format(peak.total)}',
      ),
      (
        'Transaksi terbesar',
        '${CurrencyFormatter.format(largest.amount)} · '
            '${_transactionTitle(largest)} · '
            '${DateFormatter.formatDate(largest.occurredAt)}',
      ),
      if (rate != null)
        rate >= 0
            ? ('Sisa dari pemasukan', _percent(rate))
            : ('Melebihi pemasukan', _percent(-rate)),
    ];
    return _section('Sorotan', rowCount: rows.length, [
      pw.Table(
        columnWidths: const {
          0: pw.FixedColumnWidth(115),
          1: pw.FlexColumnWidth(),
        },
        children: [
          for (final row in rows)
            pw.TableRow(
              children: [
                _cell(row.$1, color: _secondary),
                _cell(row.$2, maxLines: 2),
              ],
            ),
        ],
      ),
    ]);
  }

  List<pw.Widget> _expenseCategories() {
    if (data.expenseCategories.isEmpty) return const [];
    return _section(
      'Pengeluaran per Kategori',
      rowCount: data.expenseCategories.length,
      [
        _categoryTable(
          data.expenseCategories,
          total: data.totalExpense,
          previousTotal: data.previousExpense,
        ),
      ],
    );
  }

  List<pw.Widget> _incomeCategories() {
    if (data.incomeCategories.isEmpty) return const [];
    return _section(
      'Pemasukan per Kategori',
      rowCount: data.incomeCategories.length,
      [
        _categoryTable(
          data.incomeCategories,
          total: data.totalIncome,
          previousTotal: data.previousIncome,
        ),
      ],
    );
  }

  pw.Widget _categoryTable(
    List<ReportLine> lines, {
    required int total,
    required int previousTotal,
  }) {
    final largest = lines.first.total;
    return pw.Table(
      columnWidths: const {
        0: pw.FlexColumnWidth(3.1),
        1: pw.FlexColumnWidth(2.6),
        2: pw.FixedColumnWidth(82),
        3: pw.FixedColumnWidth(34),
        4: pw.FixedColumnWidth(30),
        5: pw.FixedColumnWidth(50),
      },
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
      ),
      children: [
        pw.TableRow(
          repeat: true,
          children: [
            _headerCell('Kategori'),
            _headerCell(''),
            _headerCell('Jumlah', right: true),
            _headerCell('Porsi', right: true),
            _headerCell('Trx', right: true),
            _headerCell('Perubahan', right: true),
          ],
        ),
        for (final line in lines)
          pw.TableRow(
            verticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              _cell(_safe(line.name).ifEmpty('-'), maxLines: 2),
              _bar(line.total / largest),
              _cell(CurrencyFormatter.format(line.total), right: true),
              _cell(_percent(line.share), right: true),
              _cell('${line.count}', right: true),
              _cell(
                _changeShort(line.total, line.previousTotal),
                right: true,
                color: _secondary,
              ),
            ],
          ),
        pw.TableRow(
          children: [
            _cell('Total', bold: true),
            pw.SizedBox(),
            _cell(CurrencyFormatter.format(total), right: true, bold: true),
            _cell('100%', right: true, bold: true),
            _cell(
              '${lines.fold<int>(0, (acc, l) => acc + l.count)}',
              right: true,
              bold: true,
            ),
            _cell(
              _changeShort(total, previousTotal),
              right: true,
              color: _secondary,
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _bar(double fraction) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6),
      child: pw.LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints!.maxWidth * fraction.clamp(0.0, 1.0);
          return pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Container(
              width: width < 1.5 ? 1.5 : width,
              height: 6,
              decoration: const pw.BoxDecoration(
                color: _ink,
                borderRadius: pw.BorderRadius.horizontal(
                  right: pw.Radius.circular(2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<pw.Widget> _trend() {
    final points = data.trend;
    final peak = points.fold<int>(0, (m, p) => p.total > m ? p.total : m);
    if (peak == 0 || points.length < 2) return const [];

    final axisMax = _niceCeiling(peak);
    const plotHeight = 110.0;
    const axisWidth = 46.0;
    final peakPoint = points.firstWhere((p) => p.total == peak);
    final labelEvery = data.trendIsMonthly
        ? (points.length <= 12 ? 1 : 3)
        : (points.length <= 10 ? 1 : 5);

    pw.Widget gridLine() => pw.Container(height: 0.5, color: _rule);
    pw.Widget axisLabel(int value) => pw.Text(
          CurrencyFormatter.formatCompact(value),
          style: const pw.TextStyle(fontSize: 7, color: _secondary),
        );

    return _section(
        data.trendIsMonthly ? 'Pengeluaran per Bulan' : 'Pengeluaran per Hari',
        rowCount: 8,
        [
          pw.SizedBox(
            height: plotHeight,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.SizedBox(
                  width: axisWidth,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      axisLabel(axisMax),
                      axisLabel(axisMax ~/ 2),
                      axisLabel(0),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Stack(
                    fit: pw.StackFit.expand,
                    children: [
                      pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [gridLine(), gridLine(), gridLine()],
                      ),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          for (final point in points)
                            pw.Expanded(
                              child: _trendBar(
                                point,
                                plotHeight * point.total / axisMax,
                                isPeak: identical(point, peakPoint),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.SizedBox(width: axisWidth),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    // Total flex harus sama dengan jumlah batang agar label tepat di
                    // bawah batangnya. Sisa yang terlalu sempit untuk label dibiarkan
                    // kosong.
                    for (var i = 0;
                        i + labelEvery <= points.length;
                        i += labelEvery)
                      pw.Expanded(
                        flex: labelEvery,
                        child: pw.Text(
                          _trendLabel(points[i]),
                          style: const pw.TextStyle(
                            fontSize: 7,
                            color: _secondary,
                          ),
                        ),
                      ),
                    if (points.length % labelEvery != 0)
                      pw.Expanded(
                        flex: points.length % labelEvery,
                        child: pw.SizedBox(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Tertinggi: ${_trendPeakLabel(peakPoint)} · '
            '${CurrencyFormatter.format(peak)} (batang paling gelap)',
            style: const pw.TextStyle(fontSize: 8, color: _secondary),
          ),
        ]);
  }

  pw.Widget _trendBar(
    ReportTrendPoint point,
    double height, {
    required bool isPeak,
  }) {
    if (point.total == 0) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 1),
      child: pw.Container(
        height: height < 1 ? 1 : height,
        decoration: pw.BoxDecoration(
          color: isPeak ? _ink : _mutedBar,
          borderRadius: const pw.BorderRadius.vertical(
            top: pw.Radius.circular(1.5),
          ),
        ),
      ),
    );
  }

  List<pw.Widget> _wallets() {
    if (data.expenseWallets.isEmpty) return const [];
    return _section(
        'Pengeluaran per Dompet',
        rowCount: data.expenseWallets.length,
        [
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(),
              1: pw.FixedColumnWidth(90),
              2: pw.FixedColumnWidth(40),
              3: pw.FixedColumnWidth(36),
            },
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
            ),
            children: [
              pw.TableRow(
                repeat: true,
                children: [
                  _headerCell('Dompet'),
                  _headerCell('Jumlah', right: true),
                  _headerCell('Porsi', right: true),
                  _headerCell('Trx', right: true),
                ],
              ),
              for (final line in data.expenseWallets)
                pw.TableRow(
                  children: [
                    _cell(_safe(line.name).ifEmpty('-'), maxLines: 2),
                    _cell(CurrencyFormatter.format(line.total), right: true),
                    _cell(_percent(line.share), right: true),
                    _cell('${line.count}', right: true),
                  ],
                ),
            ],
          ),
        ]);
  }

  List<pw.Widget> _details() {
    if (data.expenseCategories.isEmpty) return const [];
    const columns = {
      0: pw.FixedColumnWidth(70),
      1: pw.FlexColumnWidth(),
      2: pw.FixedColumnWidth(90),
      3: pw.FixedColumnWidth(82),
    };
    const border = pw.TableBorder(
      horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
    );
    pw.TableRow row(TransactionModel t) => pw.TableRow(
          children: [
            _cell(DateFormatter.formatDate(t.occurredAt), color: _secondary),
            _cell(_safe(t.note ?? '').ifEmpty('-'), maxLines: 2),
            _cell(_safe(t.walletName ?? '').ifEmpty('-'), maxLines: 1),
            _cell(CurrencyFormatter.format(t.amount), right: true),
          ],
        );

    final widgets = <pw.Widget>[];
    for (final line in data.expenseCategories) {
      // Dua baris pertama digabung dengan judul kategori agar judul tidak
      // tertinggal sendirian di dasar halaman. Sisanya bebas pindah halaman.
      final firstRows = line.transactions.take(2).map(row).toList();
      final otherRows = line.transactions.skip(2).map(row).toList();
      widgets.add(
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (widgets.isEmpty) _sectionTitle('Rincian Pengeluaran'),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '${_safe(line.name).ifEmpty('-')} (${line.count})',
                      maxLines: 1,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Text(
                    CurrencyFormatter.format(line.total),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Container(height: 0.75, color: _ink),
              pw.Table(
                  columnWidths: columns, border: border, children: firstRows),
            ],
          ),
        ),
      );
      if (otherRows.isNotEmpty) {
        widgets.add(
          pw.Table(columnWidths: columns, border: border, children: otherRows),
        );
      }
    }
    return widgets;
  }

  pw.Widget _footer(pw.Context context) {
    const style = pw.TextStyle(fontSize: 7.5, color: _secondary);
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Tally · ${data.period.label}', style: style),
          pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: style,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- Bantuan

  /// Bagian pendek disimpan utuh dalam satu halaman. Bagian yang bisa lebih
  /// panjang dari satu halaman dibiarkan mengalir, karena Inseparable yang tidak
  /// muat di halaman kosong akan membuat MultiPage gagal. Batas 20 baris tetap
  /// muat walau semua namanya memakai dua baris.
  List<pw.Widget> _section(
    String title,
    List<pw.Widget> children, {
    required int rowCount,
  }) {
    final spacing = pw.SizedBox(height: 18);
    if (rowCount > 20) return [_sectionTitle(title), ...children, spacing];
    return [
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [_sectionTitle(title), ...children],
        ),
      ),
      spacing,
    ];
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _headerCell(String text, {bool right = false}) {
    return _cell(text, right: right, color: _secondary, fontSize: 8);
  }

  pw.Widget _cell(
    String text, {
    bool right = false,
    bool bold = false,
    PdfColor color = _ink,
    double fontSize = 9,
    int? maxLines,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 2),
      child: pw.Text(
        text,
        maxLines: maxLines,
        textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _transactionTitle(TransactionModel t) {
    final note = _safe(t.note ?? '');
    return note.isNotEmpty ? note : _safe(t.categoryName ?? 'Tanpa Kategori');
  }

  /// Membuang karakter yang tidak ada di font (misalnya emoji pada catatan),
  /// yang kalau dibiarkan akan tercetak sebagai kotak kosong.
  String _safe(String text) {
    final kept = text.runes.where((r) => _glyphs.containsKey(r) || r == 0x20);
    return String.fromCharCodes(kept).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _percent(double fraction) {
    final value = fraction * 100;
    if (value > 0 && value < 1) return '<1%';
    return '${value.round()}%';
  }

  String _signedAmount(int value) {
    final formatted = CurrencyFormatter.format(value.abs());
    return value < 0 ? '−$formatted' : formatted;
  }

  String _changeShort(int current, int? previous) {
    if (previous == null || previous == 0) return 'Baru';
    final change = ((current - previous) / previous * 100).round();
    if (change == 0) return 'Tetap';
    return change > 0 ? '+$change%' : '−${change.abs()}%';
  }

  String _changeSentence(int current, int previous) {
    if (previous == 0) return 'Tidak ada data pembanding';
    final change = ((current - previous) / previous * 100).round();
    if (change == 0) return 'Sama seperti sebelumnya';
    return change > 0 ? 'Naik $change%' : 'Turun ${change.abs()}%';
  }

  String _trendLabel(ReportTrendPoint point) => data.trendIsMonthly
      ? DateFormat('MMM yy', 'id_ID').format(point.date)
      : DateFormat('d/M', 'id_ID').format(point.date);

  String _trendPeakLabel(ReportTrendPoint point) => data.trendIsMonthly
      ? DateFormatter.formatMonthYear(point.date)
      : DateFormatter.formatFullDay(point.date);

  /// Pembulatan ke atas ke angka mudah dibaca (1, 2, 5, 10 × 10ⁿ) untuk sumbu.
  int _niceCeiling(int value) {
    var magnitude = 1;
    while (magnitude * 10 <= value) {
      magnitude *= 10;
    }
    for (final step in const [1, 2, 5, 10]) {
      if (step * magnitude >= value) return step * magnitude;
    }
    return 10 * magnitude;
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
