import '../core/database/database_helper.dart';
import '../models/maintenance_record.dart';

class MaintenanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> create(MaintenanceRecord record) async {
    return await _dbHelper.insert('maintenance_records', record.toMap());
  }

  Future<List<MaintenanceRecord>> getAll() async {
    final sql = '''
      SELECT m.*, a.name as asset_name 
      FROM maintenance_records m
      JOIN assets a ON m.asset_id = a.id
      ORDER BY m.date DESC
    ''';
    final result = await _dbHelper.rawQuery(sql);
    return result.map((map) => MaintenanceRecord.fromMap(map)).toList();
  }

  Future<List<MaintenanceRecord>> getByAssetId(int assetId) async {
    final sql = '''
      SELECT m.*, a.name as asset_name 
      FROM maintenance_records m
      JOIN assets a ON m.asset_id = a.id
      WHERE m.asset_id = ?
      ORDER BY m.date DESC
    ''';
    final result = await _dbHelper.rawQuery(sql, [assetId]);
    return result.map((map) => MaintenanceRecord.fromMap(map)).toList();
  }

  Future<int> update(MaintenanceRecord record) async {
    return await _dbHelper.update(
      'maintenance_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> delete(int id) async {
    return await _dbHelper.delete(
      'maintenance_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
