enum BudgetPeriod {
  daily('daily', 'Harian', '/ hari'),
  weekly('weekly', 'Mingguan', '/ minggu'),
  monthly('monthly', 'Bulanan', '/ bulan'),
  custom('custom', 'Bebas', '');

  final String value;
  final String label;
  final String rateLabel;

  const BudgetPeriod(this.value, this.label, this.rateLabel);

  static BudgetPeriod fromString(String? val) {
    if (val == 'weekly' || val == 'mingguan') return BudgetPeriod.weekly;
    if (val == 'monthly' || val == 'bulanan') return BudgetPeriod.monthly;
    if (val == 'custom' || val == 'bebas') return BudgetPeriod.custom;
    return BudgetPeriod.daily;
  }
}

class DailyBudgetModel {
  final String id;
  final String name;
  final int dailyLimit;
  final String startDate; // YYYY-MM-DD (Siklus aktif)
  final String? endDate; // YYYY-MM-DD (Siklus aktif), nullable
  final String? baseStartDate; // Inception start date (di database)
  final String? baseEndDate; // Inception end date (di database)
  final BudgetPeriod period;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined / calculated fields (penggunaan pada periode/tanggal lokal tertentu)
  final int spent;

  const DailyBudgetModel({
    required this.id,
    required this.name,
    required this.dailyLimit,
    required this.startDate,
    this.endDate,
    this.baseStartDate,
    this.baseEndDate,
    this.period = BudgetPeriod.daily,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.spent = 0,
  });

  int get limit => dailyLimit;
  int get remaining => dailyLimit - spent;
  double get percentage => dailyLimit > 0 ? (spent / dailyLimit).clamp(0.0, 1.0) : 0;
  bool get isOverBudget => spent > dailyLimit;

  bool get isDaily => period == BudgetPeriod.daily;
  bool get isWeekly => period == BudgetPeriod.weekly;
  bool get isMonthly => period == BudgetPeriod.monthly;
  bool get isCustom => period == BudgetPeriod.custom;

  DailyBudgetModel copyWith({
    String? id,
    String? name,
    int? dailyLimit,
    String? startDate,
    String? endDate,
    String? baseStartDate,
    String? baseEndDate,
    BudgetPeriod? period,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? spent,
  }) {
    return DailyBudgetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      baseStartDate: baseStartDate ?? this.baseStartDate,
      baseEndDate: baseEndDate ?? this.baseEndDate,
      period: period ?? this.period,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      spent: spent ?? this.spent,
    );
  }

  /// Menghitung siklus aktif kuota untuk tanggal target tertentu (targetDate).
  /// - Harian: siklus per hari targetDate.
  /// - Mingguan: berulang setiap 7 hari dari baseStartDate.
  /// - Bulanan: berulang setiap bulan (tanggal 1 s/d akhir bulan, atau tanggal gajian).
  /// - Bebas: berulang setiap periode durasi hari awal yang dipilih pengguna.
  static ({DateTime startDate, DateTime? endDate}) calculateActiveCycle({
    required BudgetPeriod period,
    required DateTime baseStartDate,
    DateTime? baseEndDate,
    required DateTime targetDate,
  }) {
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final baseStart = DateTime(baseStartDate.year, baseStartDate.month, baseStartDate.day);
    final baseEnd = baseEndDate != null
        ? DateTime(baseEndDate.year, baseEndDate.month, baseEndDate.day)
        : null;

    switch (period) {
      case BudgetPeriod.daily:
        return (startDate: target, endDate: null);

      case BudgetPeriod.weekly:
        if (target.isBefore(baseStart)) {
          return (startDate: baseStart, endDate: baseStart.add(const Duration(days: 6)));
        }
        final diffDays = target.difference(baseStart).inDays;
        final cycleIndex = diffDays ~/ 7;
        final cycleStart = baseStart.add(Duration(days: cycleIndex * 7));
        final cycleEnd = cycleStart.add(const Duration(days: 6));
        return (startDate: cycleStart, endDate: cycleEnd);

      case BudgetPeriod.monthly:
        if (baseStart.day == 1) {
          final cycleStart = DateTime(target.year, target.month, 1);
          final cycleEnd = DateTime(target.year, target.month + 1, 0);
          return (startDate: cycleStart, endDate: cycleEnd);
        } else {
          final day = baseStart.day;
          if (target.day >= day) {
            final cycleStart = DateTime(target.year, target.month, day);
            final nextMonthLastDay = DateTime(target.year, target.month + 2, 0).day;
            final endDay = (day - 1).clamp(1, nextMonthLastDay);
            final cycleEnd = DateTime(target.year, target.month + 1, endDay);
            return (startDate: cycleStart, endDate: cycleEnd);
          } else {
            final prevMonthLastDay = DateTime(target.year, target.month, 0).day;
            final startDay = day.clamp(1, prevMonthLastDay);
            final cycleStart = DateTime(target.year, target.month - 1, startDay);
            final currentMonthLastDay = DateTime(target.year, target.month + 1, 0).day;
            final endDay = (day - 1).clamp(1, currentMonthLastDay);
            final cycleEnd = DateTime(target.year, target.month, endDay);
            return (startDate: cycleStart, endDate: cycleEnd);
          }
        }

      case BudgetPeriod.custom:
        if (baseEnd == null || baseEnd.isBefore(baseStart)) {
          return (startDate: baseStart, endDate: baseEnd);
        }
        final durationDays = baseEnd.difference(baseStart).inDays + 1;
        if (durationDays <= 1) {
          return (startDate: target, endDate: target);
        }
        if (target.isBefore(baseStart)) {
          return (startDate: baseStart, endDate: baseEnd);
        }
        final diffDays = target.difference(baseStart).inDays;
        final cycleIndex = diffDays ~/ durationDays;
        final cycleStart = baseStart.add(Duration(days: cycleIndex * durationDays));
        final cycleEnd = cycleStart.add(Duration(days: durationDays - 1));
        return (startDate: cycleStart, endDate: cycleEnd);
    }
  }

  ({DateTime startDate, DateTime? endDate}) getActiveCycle(DateTime targetDate) {
    final effectiveBaseStart = DateTime.tryParse(baseStartDate ?? startDate) ?? targetDate;
    final effectiveBaseEnd = (baseEndDate ?? endDate) != null
        ? DateTime.tryParse((baseEndDate ?? endDate)!)
        : null;
    return calculateActiveCycle(
      period: period,
      baseStartDate: effectiveBaseStart,
      baseEndDate: effectiveBaseEnd,
      targetDate: targetDate,
    );
  }

  factory DailyBudgetModel.fromMap(
    Map<String, dynamic> map, {
    int? calculatedSpent,
    DateTime? forDate,
  }) {
    final rawStart = map['start_date'] as String;
    final rawEnd = map['end_date'] as String?;
    final period = BudgetPeriod.fromString(map['period'] as String?);

    String effectiveStart = rawStart;
    String? effectiveEnd = rawEnd;

    if (forDate != null) {
      final baseStart = DateTime.tryParse(rawStart) ?? forDate;
      final baseEnd = rawEnd != null ? DateTime.tryParse(rawEnd) : null;
      final cycle = calculateActiveCycle(
        period: period,
        baseStartDate: baseStart,
        baseEndDate: baseEnd,
        targetDate: forDate,
      );
      effectiveStart =
          '${cycle.startDate.year.toString().padLeft(4, '0')}-${cycle.startDate.month.toString().padLeft(2, '0')}-${cycle.startDate.day.toString().padLeft(2, '0')}';
      effectiveEnd = cycle.endDate != null
          ? '${cycle.endDate!.year.toString().padLeft(4, '0')}-${cycle.endDate!.month.toString().padLeft(2, '0')}-${cycle.endDate!.day.toString().padLeft(2, '0')}'
          : null;
    }

    return DailyBudgetModel(
      id: map['id'] as String,
      name: map['name'] as String,
      dailyLimit: (map['daily_limit'] as num).toInt(),
      startDate: effectiveStart,
      endDate: effectiveEnd,
      baseStartDate: rawStart,
      baseEndDate: rawEnd,
      period: period,
      isActive: (map['is_active'] as int?) != 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      spent: calculatedSpent ?? (map['spent'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'daily_limit': dailyLimit,
      'start_date': baseStartDate ?? startDate,
      'end_date': baseEndDate ?? endDate,
      'period': period.value,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

typedef BudgetModel = DailyBudgetModel;
