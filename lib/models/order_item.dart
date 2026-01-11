class OrderItem {
  final int? id;
  final int orderId;
  final int serviceId;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final String? notes;

  OrderItem({
    this.id,
    required this.orderId,
    required this.serviceId,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'service_id': serviceId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
      'notes': notes,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int,
      serviceId: map['service_id'] as int,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }

  OrderItem copyWith({
    int? id,
    int? orderId,
    int? serviceId,
    double? quantity,
    double? unitPrice,
    double? subtotal,
    String? notes,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      serviceId: serviceId ?? this.serviceId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
      notes: notes ?? this.notes,
    );
  }
}
