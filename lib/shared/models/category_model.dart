enum CategoryType { income, expense }

extension CategoryTypeX on CategoryType {
  String get value => this == CategoryType.income ? 'income' : 'expense';

  static CategoryType fromString(String value) =>
      value == 'income' ? CategoryType.income : CategoryType.expense;
}

class CategoryModel {
  final String id;
  final String name;
  final CategoryType type;
  final String? icon;
  final String? color;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    CategoryType? type,
    String? icon,
    String? color,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: CategoryTypeX.fromString(map['type'] as String),
      icon: map['icon'] as String?,
      color: map['color'] as String?,
      isArchived: (map['is_archived'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.value,
      'icon': icon,
      'color': color,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class CategoryChartItem {
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final CategoryType type;
  final int totalAmount;
  final int transactionCount;
  final double percentage; // 0.0 - 1.0

  const CategoryChartItem({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.type,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentage,
  });

  CategoryChartItem copyWith({
    String? categoryId,
    String? categoryName,
    String? categoryIcon,
    String? categoryColor,
    CategoryType? type,
    int? totalAmount,
    int? transactionCount,
    double? percentage,
  }) {
    return CategoryChartItem(
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      categoryColor: categoryColor ?? this.categoryColor,
      type: type ?? this.type,
      totalAmount: totalAmount ?? this.totalAmount,
      transactionCount: transactionCount ?? this.transactionCount,
      percentage: percentage ?? this.percentage,
    );
  }
}
