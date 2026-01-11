class Order {
  final int? id;
  final String orderCode;
  final String barcode;
  final int customerId;
  final int employeeId;
  final String status; // 'received', 'washing', 'washed', 'delivered'
  final double totalAmount;
  final double paidAmount;
  final String? paymentMethod; // 'cash', 'bank_transfer'
  final String? notes;
  final DateTime receivedDate;
  final DateTime? deliveryDate;
  final DateTime? completedDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    this.id,
    required this.orderCode,
    required this.barcode,
    required this.customerId,
    required this.employeeId,
    required this.status,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.paymentMethod,
    this.notes,
    DateTime? receivedDate,
    this.deliveryDate,
    this.completedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : receivedDate = receivedDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_code': orderCode,
      'barcode': barcode,
      'customer_id': customerId,
      'employee_id': employeeId,
      'status': status,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'payment_method': paymentMethod,
      'notes': notes,
      'received_date': receivedDate.toIso8601String(),
      'delivery_date': deliveryDate?.toIso8601String(),
      'completed_date': completedDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as int?,
      orderCode: map['order_code'] as String,
      barcode: map['barcode'] as String,
      customerId: map['customer_id'] as int,
      employeeId: map['employee_id'] as int,
      status: map['status'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paidAmount: (map['paid_amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String?,
      notes: map['notes'] as String?,
      receivedDate: DateTime.parse(map['received_date'] as String),
      deliveryDate: map['delivery_date'] != null
          ? DateTime.parse(map['delivery_date'] as String)
          : null,
      completedDate: map['completed_date'] != null
          ? DateTime.parse(map['completed_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  bool get isPaid => paidAmount >= totalAmount;
  double get remainingAmount => totalAmount - paidAmount;

  Order copyWith({
    int? id,
    String? orderCode,
    String? barcode,
    int? customerId,
    int? employeeId,
    String? status,
    double? totalAmount,
    double? paidAmount,
    String? paymentMethod,
    String? notes,
    DateTime? receivedDate,
    DateTime? deliveryDate,
    DateTime? completedDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      orderCode: orderCode ?? this.orderCode,
      barcode: barcode ?? this.barcode,
      customerId: customerId ?? this.customerId,
      employeeId: employeeId ?? this.employeeId,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      receivedDate: receivedDate ?? this.receivedDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      completedDate: completedDate ?? this.completedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
