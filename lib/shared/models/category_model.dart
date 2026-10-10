enum CategoryType { income, expense }

extension CategoryTypeX on CategoryType {
  String get value => this == CategoryType.income ? 'income' : 'expense';

  static CategoryType fromString(String value) =>
      value == 'income' ? CategoryType.income : CategoryType.expense;
}

class CategoryModel {
  final int? id;
  final String name;
  final String? icon;
  final int? color;
  final CategoryType type;
  final DateTime createdAt;

  const CategoryModel({
    this.id,
    required this.name,
    this.icon,
    this.color,
    required this.type,
    required this.createdAt,
  });

  CategoryModel copyWith({
    int? id,
    String? name,
    String? icon,
    int? color,
    CategoryType? type,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String?,
      color: map['color'] as int?,
      type: CategoryTypeX.fromString(map['type'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'type': type.value,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
