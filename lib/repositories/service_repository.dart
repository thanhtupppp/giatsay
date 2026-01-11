import '../core/database/database_helper.dart';
import '../models/service.dart';

class ServiceRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Service service) async {
    return await _db.insert('services', service.toMap());
  }

  Future<List<Service>> getAll({bool? activeOnly, String? category}) async {
    String? where;
    List<dynamic>? whereArgs;

    if (activeOnly == true && category != null) {
      where = 'is_active = 1 AND category = ?';
      whereArgs = [category];
    } else if (activeOnly == true) {
      where = 'is_active = 1';
    } else if (category != null) {
      where = 'category = ?';
      whereArgs = [category];
    }

    final results = await _db.query(
      'services',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return results.map((map) => Service.fromMap(map)).toList();
  }

  Future<Service?> getById(int id) async {
    final results = await _db.query(
      'services',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return Service.fromMap(results.first);
  }

  Future<List<String>> getAllCategories() async {
    final results = await _db.rawQuery('''
      SELECT DISTINCT category 
      FROM services 
      WHERE category IS NOT NULL
      ORDER BY category
    ''');

    return results.map((row) => row['category'] as String).toList();
  }

  Future<int> update(Service service) async {
    return await _db.update(
      'services',
      service.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [service.id],
    );
  }

  Future<int> toggleActive(int id, bool isActive) async {
    return await _db.update(
      'services',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    return await _db.delete(
      'services',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getMostUsedServices({int limit = 10}) async {
    return await _db.rawQuery('''
      SELECT 
        s.*,
        COUNT(oi.id) as usage_count,
        SUM(oi.subtotal) as total_revenue
      FROM services s
      LEFT JOIN order_items oi ON s.id = oi.service_id
      GROUP BY s.id
      ORDER BY usage_count DESC
      LIMIT ?
    ''', [limit]);
  }
  
  // Alias for getMostUsedServices
  Future<List<Map<String, dynamic>>> getTopServices({int limit = 5}) => getMostUsedServices(limit: limit);
}

