enum TransactionType { income, expense, transfer }

extension TransactionTypeX on TransactionType {
  String get value {
    switch (this) {
      case TransactionType.income:
        return 'income';
      case TransactionType.expense:
        return 'expense';
      case TransactionType.transfer:
        return 'transfer';
    }
  }

  String get label {
    switch (this) {
      case TransactionType.income:
        return 'Pemasukan';
      case TransactionType.expense:
        return 'Pengeluaran';
      case TransactionType.transfer:
        return 'Transfer';
    }
  }

  static TransactionType fromString(String value) {
    switch (value) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      case 'transfer':
        return TransactionType.transfer;
      default:
        return TransactionType.expense;
    }
  }
}

class TransactionModel {
  final String id;
  final TransactionType type;
  final int amount; // Rupiah integer positif
  final String? categoryId;
  final String? walletId; // income / expense
  final String? sourceWalletId; // transfer
  final String? destinationWalletId; // transfer
  final String? budgetId; // kuota harian untuk expense
  final DateTime occurredAt;
  final String localDate; // YYYY-MM-DD
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined display fields
  final String? categoryName;
  final String? categoryIcon;
  final String? walletName;
  final String? sourceWalletName;
  final String? destinationWalletName;
  final String? budgetName;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    this.walletId,
    this.sourceWalletId,
    this.destinationWalletId,
    this.budgetId,
    required this.occurredAt,
    required this.localDate,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryIcon,
    this.walletName,
    this.sourceWalletName,
    this.destinationWalletName,
    this.budgetName,
  });

  TransactionModel copyWith({
    String? id,
    TransactionType? type,
    int? amount,
    String? categoryId,
    String? walletId,
    String? sourceWalletId,
    String? destinationWalletId,
    String? budgetId,
    DateTime? occurredAt,
    String? localDate,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryName,
    String? categoryIcon,
    String? walletName,
    String? sourceWalletName,
    String? destinationWalletName,
    String? budgetName,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      sourceWalletId: sourceWalletId ?? this.sourceWalletId,
      destinationWalletId: destinationWalletId ?? this.destinationWalletId,
      budgetId: budgetId ?? this.budgetId,
      occurredAt: occurredAt ?? this.occurredAt,
      localDate: localDate ?? this.localDate,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryName: categoryName ?? this.categoryName,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      walletName: walletName ?? this.walletName,
      sourceWalletName: sourceWalletName ?? this.sourceWalletName,
      destinationWalletName: destinationWalletName ?? this.destinationWalletName,
      budgetName: budgetName ?? this.budgetName,
    );
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      type: TransactionTypeX.fromString(map['type'] as String),
      amount: (map['amount'] as num).toInt(),
      categoryId: map['category_id'] as String?,
      walletId: map['wallet_id'] as String?,
      sourceWalletId: map['source_wallet_id'] as String?,
      destinationWalletId: map['destination_wallet_id'] as String?,
      budgetId: map['budget_id'] as String?,
      occurredAt: DateTime.parse(map['occurred_at'] as String),
      localDate: map['local_date'] as String,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      categoryName: map['category_name'] as String?,
      categoryIcon: map['category_icon'] as String?,
      walletName: map['wallet_name'] as String?,
      sourceWalletName: map['source_wallet_name'] as String?,
      destinationWalletName: map['destination_wallet_name'] as String?,
      budgetName: map['budget_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'amount': amount,
      'category_id': categoryId,
      'wallet_id': walletId,
      'source_wallet_id': sourceWalletId,
      'destination_wallet_id': destinationWalletId,
      'budget_id': budgetId,
      'occurred_at': occurredAt.toIso8601String(),
      'local_date': localDate,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
