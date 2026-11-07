import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tally/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:tally/shared/models/report_model.dart';

final reportPeriodProvider = StateProvider.autoDispose<ReportPeriod>((ref) {
  return ReportPeriod.thisMonth(DateTime.now());
});

final reportDataProvider = FutureProvider.autoDispose<ReportData>((ref) async {
  ref.watch(transactionsVersionProvider);
  final period = ref.watch(reportPeriodProvider);
  final previous = period.previous;
  final repo = ref.read(transactionRepositoryProvider);

  // limit: -1 = tanpa batas di SQLite. Batas bawaan getAll (100 baris) akan
  // membuat total laporan kurang tanpa ada tanda apa pun.
  final results = await Future.wait([
    repo.getAll(startDate: period.startKey, endDate: period.endKey, limit: -1),
    repo.getAll(
      startDate: previous.startKey,
      endDate: previous.endKey,
      limit: -1,
    ),
  ]);

  return ReportData.compute(
    period: period,
    transactions: results[0],
    previousTransactions: results[1],
    generatedAt: DateTime.now(),
  );
});
