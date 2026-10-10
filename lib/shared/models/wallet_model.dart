class WalletModel {
  final String id;
  final String name;
  final String type; // 'cash', 'bank', 'e-wallet', 'other'
  final int openingBalance;
  final int currentBalance; // Saldo terhitung
  final String? color;
  final String? icon;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WalletModel({
    required this.id,
    required this.name,
    this.type = 'cash',
    this.openingBalance = 0,
    this.currentBalance = 0,
    this.color,
    this.icon,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  WalletModel copyWith({
    String? id,
    String? name,
    String? type,
    int? openingBalance,
    int? currentBalance,
    String? color,
    String? icon,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory WalletModel.fromMap(Map<String, dynamic> map, {int? calculatedBalance}) {
    return WalletModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String? ?? 'cash',
      openingBalance: (map['opening_balance'] as num?)?.toInt() ?? 0,
      currentBalance: calculatedBalance ?? (map['current_balance'] as num?)?.toInt() ?? (map['opening_balance'] as num?)?.toInt() ?? 0,
      color: map['color'] as String?,
      icon: map['icon'] as String?,
      isArchived: (map['is_archived'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'opening_balance': openingBalance,
      'color': color,
      'icon': icon,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
