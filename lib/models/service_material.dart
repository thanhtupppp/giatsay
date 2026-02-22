class ServiceMaterial {
  final int? id;
  final int serviceId;
  final int materialId;
  final double quantityPerUnit;
  final DateTime createdAt;

  // UI helpers
  final String? serviceName;
  final String? materialName;
  final String? materialUnit;

  ServiceMaterial({
    this.id,
    required this.serviceId,
    required this.materialId,
    required this.quantityPerUnit,
    DateTime? createdAt,
    this.serviceName,
    this.materialName,
    this.materialUnit,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'service_id': serviceId,
      'material_id': materialId,
      'quantity_per_unit': quantityPerUnit,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ServiceMaterial.fromMap(Map<String, dynamic> map) {
    return ServiceMaterial(
      id: map['id'] as int?,
      serviceId: map['service_id'] as int,
      materialId: map['material_id'] as int,
      quantityPerUnit: (map['quantity_per_unit'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      serviceName: map['service_name'] as String?,
      materialName: map['material_name'] as String?,
      materialUnit: map['material_unit'] as String?,
    );
  }

  ServiceMaterial copyWith({
    int? id,
    int? serviceId,
    int? materialId,
    double? quantityPerUnit,
    DateTime? createdAt,
    String? serviceName,
    String? materialName,
    String? materialUnit,
  }) {
    return ServiceMaterial(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      materialId: materialId ?? this.materialId,
      quantityPerUnit: quantityPerUnit ?? this.quantityPerUnit,
      createdAt: createdAt ?? this.createdAt,
      serviceName: serviceName ?? this.serviceName,
      materialName: materialName ?? this.materialName,
      materialUnit: materialUnit ?? this.materialUnit,
    );
  }
}
