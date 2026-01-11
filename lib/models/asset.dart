class Asset {
  final int? id;
  final String? code;
  final String name;
  final String? category;
  final String? serialNumber;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String? condition; // 'good', 'fair', 'poor'
  final String? location;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Asset({
    this.id,
    this.code,
    required this.name,
    this.category,
    this.serialNumber,
    this.purchaseDate,
    this.purchasePrice,
    this.condition,
    this.location,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'category': category,
      'serial_number': serialNumber,
      'purchase_date': purchaseDate?.toIso8601String(),
      'purchase_price': purchasePrice,
      'condition': condition,
      'location': location,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'] as int?,
      code: map['code'] as String?,
      name: map['name'] as String,
      category: map['category'] as String?,
      serialNumber: map['serial_number'] as String?,
      purchaseDate: map['purchase_date'] != null
          ? DateTime.parse(map['purchase_date'] as String)
          : null,
      purchasePrice: map['purchase_price'] != null
          ? (map['purchase_price'] as num).toDouble()
          : null,
      condition: map['condition'] as String?,
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Asset copyWith({
    int? id,
    String? code,
    String? name,
    String? category,
    String? serialNumber,
    DateTime? purchaseDate,
    double? purchasePrice,
    String? condition,
    String? location,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Asset(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      serialNumber: serialNumber ?? this.serialNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      condition: condition ?? this.condition,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
