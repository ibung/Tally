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

  /// Format to full IDR: Rp 1.500.000
  static String format(double amount) => _idrFormatter.format(amount);

  /// Format compact: Rp 1,5 jt
  static String formatCompact(double amount) {
    return 'Rp ${_compactFormatter.format(amount)}';
  }

  /// Parse string back to double
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

  /// Relative: Hari ini, Kemarin, or date
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    return formatDate(date);
  }
}
