import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tally/core/services/report_pdf_service.dart';
import 'package:tally/features/reports/presentation/reports_screen.dart';
import 'package:tally/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:tally/shared/models/report_model.dart';
import 'package:tally/shared/models/transaction_model.dart';
import 'package:tally/shared/repositories/transaction_repository.dart';

int _seq = 0;

TransactionModel _tx(
  TransactionType type,
  int amount,
  DateTime at, {
  String? categoryId,
  String? categoryName,
  String? walletId = 'w1',
  String? walletName = 'Tunai',
  String? note,
}) {
  final day =
      '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
  return TransactionModel(
    id: 't${_seq++}',
    type: type,
    amount: amount,
    categoryId: categoryId,
    categoryName: categoryName,
    walletId: walletId,
    walletName: walletName,
    occurredAt: at,
    localDate: day,
    note: note,
    createdAt: at,
    updatedAt: at,
  );
}

ByteData _font(String name) {
  final bytes = File('assets/fonts/$name').readAsBytesSync();
  return ByteData.sublistView(bytes);
}

Future<Uint8List> _pdf(ReportData data, {bool includeDetails = true}) {
  return ReportPdfService.build(
    data,
    regularFont: _font('Roboto-Regular.ttf'),
    boldFont: _font('Roboto-Bold.ttf'),
    includeDetails: includeDetails,
  );
}

class _FakeTransactionRepository implements TransactionRepository {
  final List<TransactionModel> transactions;
  final List<int> limits = [];

  _FakeTransactionRepository(this.transactions);

  @override
  Future<List<TransactionModel>> getAll({
    String? walletId,
    String? type,
    String? localDate,
    String? startDate,
    String? endDate,
    String? searchQuery,
    int limit = 100,
    int offset = 0,
  }) async {
    limits.add(limit);
    return transactions
        .where((t) =>
            t.localDate.compareTo(startDate!) >= 0 &&
            t.localDate.compareTo(endDate!) <= 0)
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('ReportPeriod.previous', () {
    (String, String) range(ReportPeriod p) => (p.startKey, p.endKey);

    test('bulan berjalan dibandingkan dengan tanggal yang sama bulan lalu', () {
      final p = ReportPeriod.thisMonth(DateTime(2026, 11, 7));
      expect(range(p.previous), ('2026-10-01', '2026-10-07'));
    });

    test('bulan penuh dibandingkan dengan bulan penuh sebelumnya', () {
      final p = ReportPeriod.lastMonth(DateTime(2026, 4, 15));
      expect(range(p), ('2026-03-01', '2026-03-31'));
      expect(range(p.previous), ('2026-02-01', '2026-02-28'));
    });

    test('30 Mar berjalan tidak meluap melewati akhir Februari', () {
      final p = ReportPeriod(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 30),
      );
      expect(range(p.previous), ('2026-02-01', '2026-02-28'));
    });

    test('Januari melintasi tahun', () {
      final p = ReportPeriod.thisMonth(DateTime(2026, 1, 10));
      expect(range(p.previous), ('2025-12-01', '2025-12-10'));
    });

    test('tahun berjalan dibandingkan dengan tanggal yang sama tahun lalu', () {
      final p = ReportPeriod.thisYear(DateTime(2028, 2, 29));
      expect(range(p.previous), ('2027-01-01', '2027-02-28'));
    });

    test('rentang bebas memakai jumlah hari yang sama tepat sebelumnya', () {
      final p = ReportPeriod(
        start: DateTime(2026, 11, 10),
        end: DateTime(2026, 11, 14),
      );
      expect(p.dayCount, 5);
      expect(range(p.previous), ('2026-11-05', '2026-11-09'));
    });
  });

  group('ReportData.compute', () {
    final period = ReportPeriod(
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 10),
    );

    ReportData compute(
      List<TransactionModel> current, [
      List<TransactionModel> previous = const [],
    ]) =>
        ReportData.compute(
          period: period,
          transactions: current,
          previousTransactions: previous,
          generatedAt: DateTime(2026, 11, 10, 12),
        );

    test('transfer dan koreksi saldo tidak dihitung', () {
      final data = compute([
        _tx(TransactionType.expense, 50000, DateTime(2026, 11, 2)),
        _tx(TransactionType.income, 100000, DateTime(2026, 11, 2)),
        _tx(TransactionType.transfer, 999000, DateTime(2026, 11, 2)),
        _tx(TransactionType.expense, 777000, DateTime(2026, 11, 3),
            note: 'Koreksi Saldo'),
        _tx(TransactionType.income, 888000, DateTime(2026, 11, 3),
            note: 'Koreksi Saldo'),
      ]);
      expect(data.totalExpense, 50000);
      expect(data.totalIncome, 100000);
      expect(data.net, 50000);
      expect(data.savingsRate, 0.5);
      expect(data.largestExpense!.amount, 50000);
    });

    test('kategori dikelompokkan, diurutkan, dan totalnya cocok', () {
      final data = compute([
        _tx(TransactionType.expense, 20000, DateTime(2026, 11, 2),
            categoryId: 'food', categoryName: 'Makan'),
        _tx(TransactionType.expense, 10000, DateTime(2026, 11, 1),
            categoryId: 'food', categoryName: 'Makan'),
        _tx(TransactionType.expense, 90000, DateTime(2026, 11, 3),
            categoryId: 'fun', categoryName: 'Hiburan'),
        _tx(TransactionType.expense, 5000, DateTime(2026, 11, 3)),
      ]);
      final lines = data.expenseCategories;
      expect(lines.map((l) => l.name), ['Hiburan', 'Makan', 'Tanpa Kategori']);
      expect(lines[1].total, 30000);
      expect(lines[1].count, 2);
      expect(lines[1].share, closeTo(30000 / 125000, 1e-9));
      expect(lines.fold<int>(0, (a, l) => a + l.total), data.totalExpense);
      // Rincian urut dari yang paling lama
      expect(lines[1].transactions.first.amount, 10000);
    });

    test('kategori dibandingkan dengan periode pembanding berdasarkan id', () {
      final data = compute(
        [
          _tx(TransactionType.expense, 30000, DateTime(2026, 11, 2),
              categoryId: 'food', categoryName: 'Makan'),
          _tx(TransactionType.expense, 5000, DateTime(2026, 11, 2),
              categoryId: 'new', categoryName: 'Baru'),
        ],
        [
          _tx(TransactionType.expense, 20000, DateTime(2026, 10, 2),
              categoryId: 'food', categoryName: 'Makan'),
        ],
      );
      expect(data.previousExpense, 20000);
      expect(data.expenseCategories[0].previousTotal, 20000);
      expect(data.expenseCategories[1].previousTotal, isNull);
    });

    test('tren harian mengisi hari kosong dan totalnya cocok', () {
      final data = compute([
        _tx(TransactionType.expense, 1000, DateTime(2026, 11, 1, 8)),
        _tx(TransactionType.expense, 2000, DateTime(2026, 11, 1, 20)),
        _tx(TransactionType.expense, 4000, DateTime(2026, 11, 10)),
      ]);
      expect(data.trendIsMonthly, isFalse);
      expect(data.trend, hasLength(10));
      expect(data.trend.first.total, 3000);
      expect(data.trend[1].total, 0);
      expect(data.trend.last.total, 4000);
      expect(data.peakExpenseDay!.date, DateTime(2026, 11, 10));
      expect(data.averageDailyExpense, 700);
    });

    test('rentang lebih dari 31 hari dikelompokkan per bulan', () {
      final data = ReportData.compute(
        period: ReportPeriod(
          start: DateTime(2026, 1, 15),
          end: DateTime(2026, 3, 10),
        ),
        transactions: [
          _tx(TransactionType.expense, 1000, DateTime(2026, 1, 20)),
          _tx(TransactionType.expense, 2000, DateTime(2026, 3, 9)),
        ],
        previousTransactions: const [],
        generatedAt: DateTime(2026, 3, 10),
      );
      expect(data.trendIsMonthly, isTrue);
      expect(data.trend.map((p) => p.total), [1000, 0, 2000]);
    });

    test('periode kosong aman', () {
      final data = compute(const []);
      expect(data.isEmpty, isTrue);
      expect(data.savingsRate, isNull);
      expect(data.peakExpenseDay, isNull);
      expect(data.largestExpense, isNull);
    });
  });

  group('ReportPdfService', () {
    final period = ReportPeriod(
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 30),
    );

    void expectPdf(Uint8List bytes) {
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }

    test('nama file memuat rentang tanggal', () {
      expect(
        ReportPdfService.fileName(period),
        'Laporan-Tally-2026-11-01_2026-11-30.pdf',
      );
    });

    test('catatan beremoji dan sangat panjang tidak menggagalkan PDF',
        () async {
      final data = ReportData.compute(
        period: period,
        transactions: [
          _tx(TransactionType.expense, 25000, DateTime(2026, 11, 2),
              categoryId: 'food', categoryName: 'Makan 🍜', note: 'Bakso 🍜🔥'),
          _tx(TransactionType.expense, 1000, DateTime(2026, 11, 3),
              categoryId: '🍜', categoryName: '🍜', note: '🍜'),
          _tx(TransactionType.expense, 3000, DateTime(2026, 11, 4),
              note: 'sangat panjang ' * 200, walletName: null, walletId: null),
        ],
        previousTransactions: const [],
        generatedAt: DateTime(2026, 11, 30),
      );
      expectPdf(await _pdf(data));
    });

    test('hanya pemasukan, tanpa pengeluaran', () async {
      final data = ReportData.compute(
        period: period,
        transactions: [
          _tx(TransactionType.income, 25000, DateTime(2026, 11, 2)),
        ],
        previousTransactions: const [],
        generatedAt: DateTime(2026, 11, 30),
      );
      expectPdf(await _pdf(data));
    });

    test('banyak kategori bernama panjang tetap bisa dipecah antarhalaman',
        () async {
      for (final count in [20, 21, 80]) {
        final data = ReportData.compute(
          period: period,
          transactions: [
            for (var i = 0; i < count; i++)
              _tx(
                TransactionType.expense,
                1000 + i,
                DateTime(2026, 11, 2),
                categoryId: 'c$i',
                categoryName: 'Kategori dengan nama yang sangat panjang ' * 4,
              ),
          ],
          previousTransactions: const [],
          generatedAt: DateTime(2026, 11, 30),
        );
        expectPdf(await _pdf(data));
      }
    });

    test('ribuan transaksi melewati batas 20 halaman tanpa exception',
        () async {
      final data = ReportData.compute(
        period: ReportPeriod(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 12, 31),
        ),
        transactions: [
          for (var i = 0; i < 3000; i++)
            _tx(
              TransactionType.expense,
              1000 + i,
              DateTime(2026, 1, 1 + i % 360),
              categoryId: 'c${i % 12}',
              categoryName: 'Kategori ${i % 12}',
              note: 'Transaksi $i',
            ),
        ],
        previousTransactions: const [],
        generatedAt: DateTime(2026, 12, 31),
      );
      expectPdf(await _pdf(data));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('ReportsScreen', () {
    Future<_FakeTransactionRepository> pump(
      WidgetTester tester,
      List<TransactionModel> transactions,
    ) async {
      final repo = _FakeTransactionRepository(transactions);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [transactionRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: ReportsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    FilledButton pdfButton(WidgetTester tester) => tester.widget<FilledButton>(
          find.byWidgetPredicate((w) => w is FilledButton),
        );

    testWidgets('mengambil semua transaksi tanpa batas 100 baris',
        (tester) async {
      final now = DateTime.now();
      final repo = await pump(tester, [
        for (var i = 0; i < 150; i++)
          _tx(TransactionType.expense, 1000, DateTime(now.year, now.month, 1),
              categoryId: 'food', categoryName: 'Makan'),
      ]);
      expect(repo.limits, isNotEmpty);
      expect(repo.limits, everyElement(-1));
      expect(find.text('Makan'), findsOneWidget);
      expect(pdfButton(tester).onPressed, isNotNull);
    });

    testWidgets('periode kosong menonaktifkan tombol PDF', (tester) async {
      await pump(tester, const []);
      expect(find.textContaining('Belum ada pemasukan'), findsOneWidget);
      expect(pdfButton(tester).onPressed, isNull);
    });
  });
}
