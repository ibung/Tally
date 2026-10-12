enum BudgetPeriod {
  daily('daily', 'Harian', '/ hari'),
  weekly('weekly', 'Mingguan', '/ minggu'),
  monthly('monthly', 'Bulanan', '/ bulan');

  final String value;
  final String label;
  final String rateLabel;

  const BudgetPeriod(this.value, this.label, this.rateLabel);

  static BudgetPeriod fromString(String? val) {
    if (val == 'weekly' || val == 'mingguan') return BudgetPeriod.weekly;
    if (val == 'monthly' || val == 'bulanan') return BudgetPeriod.monthly;
    return BudgetPeriod.daily;
  }
}

class DailyBudgetModel {
  final String id;
  final String name;
  final int dailyLimit;
  final String startDate; // YYYY-MM-DD
  final String? endDate; // YYYY-MM-DD, nullable
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

  DailyBudgetModel copyWith({
    String? id,
    String? name,
    int? dailyLimit,
    String? startDate,
    String? endDate,
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
      period: period ?? this.period,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      spent: spent ?? this.spent,
    );
  }

  factory DailyBudgetModel.fromMap(Map<String, dynamic> map, {int? calculatedSpent}) {
    return DailyBudgetModel(
      id: map['id'] as String,
      name: map['name'] as String,
      dailyLimit: (map['daily_limit'] as num).toInt(),
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String?,
      period: BudgetPeriod.fromString(map['period'] as String?),
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
      'start_date': startDate,
      'end_date': endDate,
      'period': period.value,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

typedef BudgetModel = DailyBudgetModel;
