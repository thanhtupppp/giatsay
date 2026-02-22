import '../core/database/database_helper.dart';
import '../models/service_material.dart';

class ServiceMaterialRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Get all mappings for a specific service (with material names)
  Future<List<ServiceMaterial>> getByServiceId(int serviceId) async {
    final results = await _db.rawQuery(
      '''
      SELECT sm.*, s.name as service_name, m.name as material_name, m.unit as material_unit
      FROM service_materials sm
      JOIN services s ON sm.service_id = s.id
      JOIN materials m ON sm.material_id = m.id
      WHERE sm.service_id = ?
      ORDER BY m.name ASC
    ''',
      [serviceId],
    );

    return results.map((map) => ServiceMaterial.fromMap(map)).toList();
  }

  /// Get all mappings (with names)
  Future<List<ServiceMaterial>> getAll() async {
    final results = await _db.rawQuery('''
      SELECT sm.*, s.name as service_name, m.name as material_name, m.unit as material_unit
      FROM service_materials sm
      JOIN services s ON sm.service_id = s.id
      JOIN materials m ON sm.material_id = m.id
      ORDER BY s.name ASC, m.name ASC
    ''');

    return results.map((map) => ServiceMaterial.fromMap(map)).toList();
  }

  /// Add a new mapping
  Future<int> create(ServiceMaterial mapping) async {
    return await _db.insert('service_materials', mapping.toMap());
  }

  /// Update quantity_per_unit
  Future<int> update(ServiceMaterial mapping) async {
    return await _db.update(
      'service_materials',
      {'quantity_per_unit': mapping.quantityPerUnit},
      where: 'id = ?',
      whereArgs: [mapping.id],
    );
  }

  /// Delete a mapping
  Future<int> delete(int id) async {
    return await _db.delete(
      'service_materials',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deduct materials for a list of order items.
  /// Each order item has `service_id` and `quantity`.
  /// For each item, find all material mappings and deduct:
  ///   material.quantity -= mapping.quantity_per_unit * orderItem.quantity
  Future<void> deductMaterialsForOrder(
    List<Map<String, dynamic>> orderItems,
  ) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      for (final item in orderItems) {
        final serviceId = item['service_id'] as int;
        final orderQty = (item['quantity'] as num).toDouble();

        // Find all material mappings for this service
        final mappings = await txn.rawQuery(
          '''
          SELECT material_id, quantity_per_unit
          FROM service_materials
          WHERE service_id = ?
        ''',
          [serviceId],
        );

        for (final mapping in mappings) {
          final materialId = mapping['material_id'] as int;
          final qtyPerUnit = (mapping['quantity_per_unit'] as num).toDouble();
          final deductAmount = qtyPerUnit * orderQty;

          // Deduct from materials table
          await txn.rawUpdate(
            '''
            UPDATE materials 
            SET quantity = MAX(0, quantity - ?),
                updated_at = ?
            WHERE id = ?
          ''',
            [deductAmount, DateTime.now().toIso8601String(), materialId],
          );
        }
      }
    });
  }
}
