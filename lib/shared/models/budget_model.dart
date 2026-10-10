enum BudgetPeriod { daily, weekly, monthly, yearly }

extension BudgetPeriodX on BudgetPeriod {
  String get value {
    switch (this) {
      case BudgetPeriod.daily:
        return 'daily';
      case BudgetPeriod.weekly:
        return 'weekly';
      case BudgetPeriod.monthly:
        return 'monthly';
      case BudgetPeriod.yearly:
        return 'yearly';
    }
  }

  String get label {
    switch (this) {
      case BudgetPeriod.daily:
        return 'Harian';
      case BudgetPeriod.weekly:
        return 'Mingguan';
      case BudgetPeriod.monthly:
        return 'Bulanan';
      case BudgetPeriod.yearly:
        return 'Tahunan';
    }
  }

  static BudgetPeriod fromString(String value) {
    switch (value) {
      case 'daily':
        return BudgetPeriod.daily;
      case 'weekly':
        return BudgetPeriod.weekly;
      case 'yearly':
        return BudgetPeriod.yearly;
      default:
        return BudgetPeriod.monthly;
    }
  }
}

class BudgetModel {
  final int? id;
  final int? categoryId;
  final double amount;
  final double spent;
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional joined fields
  final String? categoryName;
  final String? categoryIcon;
  final int? categoryColor;

  const BudgetModel({
    this.id,
    this.categoryId,
    required this.amount,
    this.spent = 0,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  double get remaining => amount - spent;
  double get percentage => amount > 0 ? (spent / amount).clamp(0.0, 1.0) : 0;
  bool get isOverBudget => spent > amount;

  BudgetModel copyWith({
    int? id,
    int? categoryId,
    double? amount,
    double? spent,
    BudgetPeriod? period,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      spent: spent ?? this.spent,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      spent: (map['spent'] as num?)?.toDouble() ?? 0,
      period: BudgetPeriodX.fromString(map['period'] as String),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
      categoryColor: map['category_color'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'amount': amount,
      'spent': spent,
      'period': period.value,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
