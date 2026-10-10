import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _idrFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _compactFormatter = NumberFormat.compact(
    locale: 'id_ID',
  );

  /// Format to full IDR: Rp 25.000
  static String format(num amount) => _idrFormatter.format(amount);

  /// Format compact: Rp 1,5 jt
  static String formatCompact(num amount) {
    return 'Rp ${_compactFormatter.format(amount)}';
  }

  /// Parse string to Rupiah integer (PRD Bab 7 & 8)
  static int parseInt(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  /// Legacy parse to double
  static double parse(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }
}

class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
  static final DateFormat _dateTimeFormatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  static final DateFormat _monthYearFormatter = DateFormat('MMMM yyyy', 'id_ID');
  static final DateFormat _dayFormatter = DateFormat('EEEE, dd MMM yyyy', 'id_ID');

  /// 15 Okt 2024
  static String formatDate(DateTime date) => _dateFormatter.format(date);

  /// 15 Okt 2024, 14:30
  static String formatDateTime(DateTime date) => _dateTimeFormatter.format(date);

  /// Oktober 2024
  static String formatMonthYear(DateTime date) => _monthYearFormatter.format(date);

  /// Senin, 15 Okt 2024
  static String formatFullDay(DateTime date) => _dayFormatter.format(date);

  /// Format DateTime to YYYY-MM-DD local date (PRD Bab 8)
  static String toLocalDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Parse YYYY-MM-DD back to DateTime
  static DateTime parseLocalDate(String localDate) {
    final parts = localDate.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  static final DateFormat _timeFormatter = DateFormat('HH:mm');

  /// 14:30
  static String formatTime(DateTime date) => _timeFormatter.format(date);

  /// Relative: Hari ini, Kemarin, Besok, or date
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff == -1) return 'Besok';
    return formatDate(date);
  }
}
