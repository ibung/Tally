import 'dart:math' as math;

import 'package:tally/core/utils/formatters.dart';
import 'package:tally/shared/models/transaction_model.dart';

/// Rentang tanggal laporan (inklusif di kedua ujung, berbasis tanggal lokal).
class ReportPeriod {
  final DateTime start;
  final DateTime end;

  ReportPeriod({required DateTime start, required DateTime end})
      : start = DateTime(start.year, start.month, start.day),
        end = DateTime(end.year, end.month, end.day);

  factory ReportPeriod.thisMonth(DateTime now) =>
      ReportPeriod(start: DateTime(now.year, now.month, 1), end: now);

  factory ReportPeriod.lastMonth(DateTime now) => ReportPeriod(
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month, 0),
      );

  factory ReportPeriod.last3Months(DateTime now) =>
      ReportPeriod(start: DateTime(now.year, now.month - 2, 1), end: now);

  factory ReportPeriod.thisYear(DateTime now) =>
      ReportPeriod(start: DateTime(now.year, 1, 1), end: now);

  String get startKey => DateFormatter.toLocalDate(start);
  String get endKey => DateFormatter.toLocalDate(end);

  /// Jumlah hari kalender. Memakai UTC agar tidak terpengaruh pergeseran DST.
  int get dayCount =>
      DateTime.utc(end.year, end.month, end.day)
          .difference(DateTime.utc(start.year, start.month, start.day))
          .inDays +
      1;

  String get label => startKey == endKey
      ? DateFormatter.formatDate(start)
      : '${DateFormatter.formatDate(start)} – ${DateFormatter.formatDate(end)}';

  /// Periode pembanding yang sebanding, supaya bulan yang baru berjalan tidak
  /// dibandingkan dengan satu bulan penuh:
  /// - 1–7 Nov dibandingkan dengan 1–7 Okt; November penuh dengan Oktober penuh
  /// - 1 Jan–7 Nov dibandingkan dengan tanggal yang sama tahun lalu
  /// - rentang lainnya dibandingkan dengan jumlah hari yang sama tepat sebelumnya
  ReportPeriod get previous {
    if (start.day == 1 && start.year == end.year) {
      if (start.month == end.month) {
        final isFullMonth = end.day == _daysInMonth(end.year, end.month);
        final prevDays = _daysInMonth(start.year, start.month - 1);
        return ReportPeriod(
          start: DateTime(start.year, start.month - 1, 1),
          end: DateTime(
            start.year,
            start.month - 1,
            isFullMonth ? prevDays : math.min(end.day, prevDays),
          ),
        );
      }
      if (start.month == 1) {
        final lastYear = start.year - 1;
        return ReportPeriod(
          start: DateTime(lastYear, 1, 1),
          end: DateTime(
            lastYear,
            end.month,
            math.min(end.day, _daysInMonth(lastYear, end.month)),
          ),
        );
      }
    }
    return ReportPeriod(
      start: DateTime(start.year, start.month, start.day - dayCount),
      end: DateTime(start.year, start.month, start.day - 1),
    );
  }

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;
}

/// Satu baris rincian (kategori atau dompet) dalam laporan.
class ReportLine {
  final String name;
  final int total;
  final int count;

  /// Porsi terhadap total bagian ini (0.0–1.0).
  final double share;

  /// Total periode pembanding; null bila baris ini tidak ada datanya di sana.
  final int? previousTotal;

  /// Transaksi penyusun, urut dari yang paling lama.
  final List<TransactionModel> transactions;

  const ReportLine({
    required this.name,
    required this.total,
    required this.count,
    required this.share,
    this.previousTotal,
    this.transactions = const [],
  });
}

class ReportTrendPoint {
  final DateTime date;
  final int total;

  const ReportTrendPoint(this.date, this.total);
}

/// Seluruh angka laporan. Dihitung dari transaksi sumber agar selalu konsisten.
class ReportData {
  static const _noneKey = '__none__';

  final ReportPeriod period;
  final ReportPeriod previousPeriod;
  final DateTime generatedAt;
  final int totalIncome;
  final int totalExpense;
  final int previousIncome;
  final int previousExpense;
  final List<ReportLine> expenseCategories;
  final List<ReportLine> incomeCategories;
  final List<ReportLine> expenseWallets;

  /// Per hari untuk rentang hingga 31 hari; selebihnya per bulan.
  final List<ReportTrendPoint> trend;
  final bool trendIsMonthly;
  final TransactionModel? largestExpense;

  const ReportData({
    required this.period,
    required this.previousPeriod,
    required this.generatedAt,
    required this.totalIncome,
    required this.totalExpense,
    required this.previousIncome,
    required this.previousExpense,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.expenseWallets,
    required this.trend,
    required this.trendIsMonthly,
    required this.largestExpense,
  });

  /// [transactions] dan [previousTransactions] boleh memuat semua jenis:
  /// transfer dan koreksi saldo dibuang di sini karena bukan arus kas.
  factory ReportData.compute({
    required ReportPeriod period,
    required List<TransactionModel> transactions,
    required List<TransactionModel> previousTransactions,
    required DateTime generatedAt,
  }) {
    List<TransactionModel> ofType(
      List<TransactionModel> source,
      TransactionType type,
    ) =>
        source.where((t) => t.type == type && !t.isCorrection).toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    int sum(List<TransactionModel> list) =>
        list.fold(0, (acc, t) => acc + t.amount);

    final expenses = ofType(transactions, TransactionType.expense);
    final incomes = ofType(transactions, TransactionType.income);
    final prevExpenses = ofType(previousTransactions, TransactionType.expense);
    final prevIncomes = ofType(previousTransactions, TransactionType.income);
    final monthly = period.dayCount > 31;

    TransactionModel? largest;
    for (final t in expenses) {
      if (largest == null || t.amount > largest.amount) largest = t;
    }

    return ReportData(
      period: period,
      previousPeriod: period.previous,
      generatedAt: generatedAt,
      totalIncome: sum(incomes),
      totalExpense: sum(expenses),
      previousIncome: sum(prevIncomes),
      previousExpense: sum(prevExpenses),
      expenseCategories: _categoryLines(expenses, prevExpenses),
      incomeCategories: _categoryLines(incomes, prevIncomes),
      expenseWallets: _lines(
        expenses,
        const [],
        keyOf: (t) => t.walletId ?? _noneKey,
        nameOf: (t) => t.walletName ?? 'Tanpa Dompet',
      ),
      trend: _trend(period, expenses, monthly),
      trendIsMonthly: monthly,
      largestExpense: largest,
    );
  }

  bool get isEmpty => totalIncome == 0 && totalExpense == 0;

  int get net => totalIncome - totalExpense;

  int get averageDailyExpense => (totalExpense / period.dayCount).round();

  /// Porsi pemasukan yang tersisa; null bila tidak ada pemasukan.
  double? get savingsRate => totalIncome > 0 ? net / totalIncome : null;

  /// Hari dengan pengeluaran terbesar di seluruh periode.
  ReportTrendPoint? get peakExpenseDay {
    final byDay = <String, int>{};
    for (final line in expenseCategories) {
      for (final t in line.transactions) {
        byDay.update(t.localDate, (v) => v + t.amount,
            ifAbsent: () => t.amount);
      }
    }
    if (byDay.isEmpty) return null;
    final top = byDay.entries.reduce((a, b) {
      if (a.value != b.value) return a.value > b.value ? a : b;
      return a.key.compareTo(b.key) <= 0 ? a : b; // seri: tanggal paling awal
    });
    return ReportTrendPoint(DateFormatter.parseLocalDate(top.key), top.value);
  }

  static List<ReportLine> _categoryLines(
    List<TransactionModel> current,
    List<TransactionModel> previous,
  ) =>
      _lines(
        current,
        previous,
        keyOf: (t) => t.categoryId ?? _noneKey,
        nameOf: (t) => t.categoryName ?? 'Tanpa Kategori',
      );

  static List<ReportLine> _lines(
    List<TransactionModel> current,
    List<TransactionModel> previous, {
    required String Function(TransactionModel) keyOf,
    required String Function(TransactionModel) nameOf,
  }) {
    final groups = <String, List<TransactionModel>>{};
    for (final t in current) {
      groups.putIfAbsent(keyOf(t), () => []).add(t);
    }
    final previousTotals = <String, int>{};
    for (final t in previous) {
      previousTotals.update(
        keyOf(t),
        (v) => v + t.amount,
        ifAbsent: () => t.amount,
      );
    }
    final grandTotal = current.fold<int>(0, (acc, t) => acc + t.amount);

    final lines = groups.entries.map((e) {
      final total = e.value.fold<int>(0, (acc, t) => acc + t.amount);
      return ReportLine(
        name: nameOf(e.value.first),
        total: total,
        count: e.value.length,
        share: grandTotal > 0 ? total / grandTotal : 0,
        previousTotal: previousTotals[e.key],
        transactions: e.value,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return lines;
  }

  /// Hari atau bulan tanpa pengeluaran tetap muncul sebagai nol, supaya
  /// sumbu waktu grafik tidak melompat.
  static List<ReportTrendPoint> _trend(
    ReportPeriod period,
    List<TransactionModel> expenses,
    bool monthly,
  ) {
    final totals = <String, int>{};
    for (final t in expenses) {
      final key = monthly ? t.localDate.substring(0, 7) : t.localDate;
      totals.update(key, (v) => v + t.amount, ifAbsent: () => t.amount);
    }

    final points = <ReportTrendPoint>[];
    var cursor = monthly
        ? DateTime(period.start.year, period.start.month, 1)
        : period.start;
    while (!cursor.isAfter(period.end)) {
      final dayKey = DateFormatter.toLocalDate(cursor);
      final key = monthly ? dayKey.substring(0, 7) : dayKey;
      points.add(ReportTrendPoint(cursor, totals[key] ?? 0));
      cursor = monthly
          ? DateTime(cursor.year, cursor.month + 1, 1)
          : DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return points;
  }
}
