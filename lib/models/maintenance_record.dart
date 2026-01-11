class MaintenanceRecord {
  final int? id;
  final int assetId;
  final String? assetName; // For display convenience
  final DateTime date;
  final String description;
  final double cost;
  final String? technician;
  final DateTime createdAt;

  MaintenanceRecord({
    this.id,
    required this.assetId,
    this.assetName,
    required this.date,
    required this.description,
    required this.cost,
    this.technician,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'asset_id': assetId,
      'date': date.toIso8601String(),
      'description': description,
      'cost': cost,
      'technician': technician,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'] as int?,
      assetId: map['asset_id'] as int,
      assetName: map['asset_name'] as String?,
      date: DateTime.parse(map['date'] as String),
      description: map['description'] as String,
      cost: (map['cost'] as num).toDouble(),
      technician: map['technician'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
