class Customer {
  final int? id;
  final String name;
  final String phone;
  final String? address;
  final String? email;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int orderCount;
  final double totalSpent;
  final DateTime? lastOrderDate;
  final String? lastOrderStatus;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.address,
    this.email,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.orderCount = 0,
    this.totalSpent = 0,
    this.lastOrderDate,
    this.lastOrderStatus,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'email': email,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      address: map['address'] as String?,
      email: map['email'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      orderCount: (map['order_count'] as int?) ?? 0,
      totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0.0,
      lastOrderDate: map['last_order_date'] != null 
          ? DateTime.parse(map['last_order_date'] as String) 
          : null,
      lastOrderStatus: map['last_order_status'] as String?,
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    String? email,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
