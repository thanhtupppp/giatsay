class MaterialItem {
  final int? id;
  final String name;
  final String unit;
  final double quantity;
  final double minQuantity;
  final double costPrice;
  final String? imagePath;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaterialItem({
    this.id,
    required this.name,
    required this.unit,
    this.quantity = 0,
    this.minQuantity = 0,
    this.costPrice = 0,
    this.imagePath,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => quantity <= minQuantity;

  MaterialItem copyWith({
    int? id,
    String? name,
    String? unit,
    double? quantity,
    double? minQuantity,
    double? costPrice,
    String? imagePath,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaterialItem(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      minQuantity: minQuantity ?? this.minQuantity,
      costPrice: costPrice ?? this.costPrice,
      imagePath: imagePath ?? this.imagePath,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'quantity': quantity,
      'min_quantity': minQuantity,
      'cost_price': costPrice,
      'image_path': imagePath,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory MaterialItem.fromMap(Map<String, dynamic> map) {
    return MaterialItem(
      id: map['id'],
      name: map['name'],
      unit: map['unit'],
      quantity: map['quantity'] ?? 0.0,
      minQuantity: map['min_quantity'] ?? 0.0,
      costPrice: map['cost_price'] ?? 0.0,
      imagePath: map['image_path'],
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}
