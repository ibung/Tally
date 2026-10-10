class DailyBudgetModel {
  final String id;
  final String name;
  final int dailyLimit;
  final String startDate; // YYYY-MM-DD
  final String? endDate; // YYYY-MM-DD, nullable
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined / calculated fields (penggunaan pada tanggal lokal tertentu)
  final int spent;

  const DailyBudgetModel({
    required this.id,
    required this.name,
    required this.dailyLimit,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.spent = 0,
  });

  int get remaining => dailyLimit - spent;
  double get percentage => dailyLimit > 0 ? (spent / dailyLimit).clamp(0.0, 1.0) : 0;
  bool get isOverBudget => spent > dailyLimit;

  DailyBudgetModel copyWith({
    String? id,
    String? name,
    int? dailyLimit,
    String? startDate,
    String? endDate,
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
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
