
import '../models/material_item.dart';
import '../core/database/database_helper.dart';

class MaterialRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final String _table = 'materials';

  Future<List<MaterialItem>> getAll({String? query}) async {
    final db = await _dbHelper.database;
    String? where;
    List<dynamic>? whereArgs;

    if (query != null && query.isNotEmpty) {
      where = 'name LIKE ?';
      whereArgs = ['%$query%'];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      _table,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) => MaterialItem.fromMap(maps[i]));
  }

  Future<MaterialItem?> getById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return MaterialItem.fromMap(maps.first);
    }
    return null;
  }

  Future<int> create(MaterialItem item) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final newItem = item.copyWith(
      createdAt: now,
      updatedAt: now,
    );
    return await db.insert(_table, newItem.toMap());
  }

  Future<int> update(MaterialItem item) async {
    final db = await _dbHelper.database;
    final newItem = item.copyWith(
      updatedAt: DateTime.now(),
    );
    return await db.update(
      _table,
      newItem.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<MaterialItem>> getLowStockItems() async {
    final db = await _dbHelper.database;
    // Quantity <= MinQuantity
    final List<Map<String, dynamic>> maps = await db.query(
      _table,
      where: 'quantity <= min_quantity',
      orderBy: 'quantity ASC',
    );

    return List.generate(maps.length, (i) => MaterialItem.fromMap(maps[i]));
  }
}
