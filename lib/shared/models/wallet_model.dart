class WalletModel {
  final int? id;
  final String name;
  final double balance;
  final String currency;
  final String? icon;
  final int? color;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WalletModel({
    this.id,
    required this.name,
    required this.balance,
    this.currency = 'IDR',
    this.icon,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  WalletModel copyWith({
    int? id,
    String? name,
    double? balance,
    String? currency,
    String? icon,
    int? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      balance: (map['balance'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'IDR',
      icon: map['icon'] as String?,
      color: map['color'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'balance': balance,
      'currency': currency,
      'icon': icon,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
