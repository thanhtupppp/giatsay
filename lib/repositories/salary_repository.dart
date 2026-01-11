import '../core/database/database_helper.dart';
import '../models/salary.dart';

class SalaryRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> create(Salary salary) async {
    return await _db.insert('salaries', salary.toMap());
  }

  Future<List<Salary>> getAll({int? employeeId, String? month, bool? paidOnly}) async {
    String? where;
    List<dynamic>? whereArgs;

    if (employeeId != null && month != null) {
      where = 'employee_id = ? AND month = ?';
      whereArgs = [employeeId, month];
    } else if (employeeId != null) {
      where = 'employee_id = ?';
      whereArgs = [employeeId];
    } else if (month != null) {
      where = 'month = ?';
      whereArgs = [month];
    }

    if (paidOnly == true) {
      where = where != null ? '$where AND paid = 1' : 'paid = 1';
    }

    final results = await _db.query(
      'salaries',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'month DESC, created_at DESC',
    );

    return results.map((map) => Salary.fromMap(map)).toList();
  }

  Future<Salary?> getById(int id) async {
    final results = await _db.query(
      'salaries',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return Salary.fromMap(results.first);
  }

  Future<Salary?> getByEmployeeAndMonth(int employeeId, String month) async {
    final results = await _db.query(
      'salaries',
      where: 'employee_id = ? AND month = ?',
      whereArgs: [employeeId, month],
    );

    if (results.isEmpty) return null;
    return Salary.fromMap(results.first);
  }

  Future<int> update(Salary salary) async {
    return await _db.update(
      'salaries',
      salary.toMap(),
      where: 'id = ?',
      whereArgs: [salary.id],
    );
  }

  Future<int> markAsPaid(int id) async {
    return await _db.update(
      'salaries',
      {
        'paid': 1,
        'paid_date': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    return await _db.delete(
      'salaries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getSalaryByEmployeeWithName() async {
    return await _db.rawQuery('''
      SELECT 
        s.*,
        u.full_name as employee_name,
        u.role as employee_role
      FROM salaries s
      INNER JOIN users u ON s.employee_id = u.id
      ORDER BY s.month DESC, s.created_at DESC
    ''');
  }

  Future<double> getTotalUnpaidSalary() async {
    final result = await _db.rawQuery('''
      SELECT SUM(total_salary) as total
      FROM salaries
      WHERE paid = 0
    ''');

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
