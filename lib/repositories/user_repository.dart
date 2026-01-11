import '../core/database/database_helper.dart';
import '../models/user.dart';

class UserRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(User user) async {
    return await _db.insert('users', user.toMap());
  }

  Future<List<User>> getAll({String? role, bool? activeOnly}) async {
    String? where;
    List<dynamic>? whereArgs;

    if (role != null && activeOnly == true) {
      where = 'role = ? AND is_active = 1';
      whereArgs = [role];
    } else if (role != null) {
      where = 'role = ?';
      whereArgs = [role];
    } else if (activeOnly == true) {
      where = 'is_active = 1';
    }

    final results = await _db.query(
      'users',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return results.map((map) => User.fromMap(map)).toList();
  }

  Future<User?> getById(int id) async {
    final results = await _db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return User.fromMap(results.first);
  }

  Future<User?> getByUsername(String username) async {
    final results = await _db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (results.isEmpty) return null;
    return User.fromMap(results.first);
  }

  Future<int> update(User user) async {
    return await _db.update(
      'users',
      user.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> toggleActive(int id, bool isActive) async {
    return await _db.update(
      'users',
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
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> usernameExists(String username, {int? excludeId}) async {
    String where = 'username = ?';
    List<dynamic> whereArgs = [username];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final results = await _db.query(
      'users',
      where: where,
      whereArgs: whereArgs,
    );

    return results.isNotEmpty;
  }
}
