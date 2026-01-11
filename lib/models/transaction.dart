class Transaction {
  final int? id;
  final String type; // 'income', 'expense'
  final String category;
  final double amount;
  final String? description;
  final int? orderId;
  final int userId;
  final DateTime transactionDate;
  final DateTime createdAt;

  Transaction({
    this.id,
    required this.type,
    required this.category,
    required this.amount,
    this.description,
    this.orderId,
    required this.userId,
    DateTime? transactionDate,
    DateTime? createdAt,
  })  : transactionDate = transactionDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'category': category,
      'amount': amount,
      'description': description,
      'order_id': orderId,
      'user_id': userId,
      'transaction_date': transactionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      type: map['type'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      orderId: map['order_id'] as int?,
      userId: map['user_id'] as int,
      transactionDate: DateTime.parse(map['transaction_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Transaction copyWith({
    int? id,
    String? type,
    String? category,
    double? amount,
    String? description,
    int? orderId,
    int? userId,
    DateTime? transactionDate,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
