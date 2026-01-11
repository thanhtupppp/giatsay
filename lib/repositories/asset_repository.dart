import '../../core/database/database_helper.dart';
import '../../models/asset.dart';

class AssetRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Asset asset) async {
    return await _db.insert('assets', asset.toMap());
  }

  Future<List<Asset>> getAll({String? category, String? condition}) async {
    String? where;
    List<dynamic>? whereArgs;

    if (category != null && condition != null) {
      where = 'category = ? AND condition = ?';
      whereArgs = [category, condition];
    } else if (category != null) {
      where = 'category = ?';
      whereArgs = [category];
    } else if (condition != null) {
      where = 'condition = ?';
      whereArgs = [condition];
    }

    final results = await _db.query(
      'assets',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return results.map((map) => Asset.fromMap(map)).toList();
  }

  Future<Asset?> getById(int id) async {
    final results = await _db.query(
      'assets',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return Asset.fromMap(results.first);
  }

  Future<int> update(Asset asset) async {
    return await _db.update(
      'assets',
      asset.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [asset.id],
    );
  }

  Future<int> delete(int id) async {
    return await _db.delete(
      'assets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<String>> getAllCategories() async {
    final results = await _db.rawQuery('''
      SELECT DISTINCT category 
      FROM assets 
      WHERE category IS NOT NULL
      ORDER BY category
    ''');

    return results.map((row) => row['category'] as String).toList();
  }

  Future<double> getTotalValue() async {
    final result = await _db.rawQuery('''
      SELECT SUM(purchase_price) as total
      FROM assets
      WHERE purchase_price IS NOT NULL
    ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
