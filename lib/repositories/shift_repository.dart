import '../models/work_shift.dart';
import '../models/timesheet.dart';
import '../core/database/database_helper.dart';

class ShiftRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final String _shiftTable = 'work_shifts';
  final String _timesheetTable = 'timesheets';

  // --- Work Shift Methods ---
  Future<List<WorkShift>> getAllShifts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _shiftTable,
      orderBy: 'start_time ASC',
    );
    return List.generate(maps.length, (i) => WorkShift.fromMap(maps[i]));
  }

  Future<List<WorkShift>> getActiveShifts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _shiftTable,
      where: 'is_active = 1',
      orderBy: 'start_time ASC',
    );
    return List.generate(maps.length, (i) => WorkShift.fromMap(maps[i]));
  }

  Future<int> createShift(WorkShift shift) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    return await db.insert(
      _shiftTable,
      shift.copyWith(createdAt: now, updatedAt: now).toMap(),
    );
  }

  Future<int> updateShift(WorkShift shift) async {
    final db = await _dbHelper.database;
    return await db.update(
      _shiftTable,
      shift.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [shift.id],
    );
  }

  Future<int> deleteShift(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(_shiftTable, where: 'id = ?', whereArgs: [id]);
  }

  // --- Timesheet Methods ---
  Future<List<Timesheet>> getTimesheets({
    int? employeeId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = '1=1';
    List<dynamic> args = [];

    if (employeeId != null) {
      whereClause += ' AND t.employee_id = ?';
      args.add(employeeId);
    }

    if (fromDate != null) {
      whereClause += ' AND t.work_date >= ?';
      args.add(fromDate.toIso8601String().split('T')[0]);
    }

    if (toDate != null) {
      whereClause += ' AND t.work_date <= ?';
      args.add(toDate.toIso8601String().split('T')[0]);
    }

    // Join with Users and WorkShifts to get names
    final String sql =
        '''
      SELECT t.*, u.full_name as employee_name, s.name as shift_name 
      FROM $_timesheetTable t
      LEFT JOIN users u ON t.employee_id = u.id
      LEFT JOIN $_shiftTable s ON t.shift_id = s.id
      WHERE $whereClause
      ORDER BY t.work_date DESC, t.check_in DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, args);
    return List.generate(maps.length, (i) => Timesheet.fromMap(maps[i]));
  }

  Future<Timesheet?> getTodayTimesheet(int employeeId) async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().split('T')[0];

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT t.*, u.full_name as employee_name, s.name as shift_name 
      FROM $_timesheetTable t
      LEFT JOIN users u ON t.employee_id = u.id
      LEFT JOIN $_shiftTable s ON t.shift_id = s.id
      WHERE t.employee_id = ? AND t.work_date = ?
    ''',
      [employeeId, today],
    );

    if (maps.isNotEmpty) {
      return Timesheet.fromMap(maps.first);
    }
    return null;
  }

  Future<int> checkIn(int employeeId, int? shiftId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];

    final timesheet = Timesheet(
      employeeId: employeeId,
      shiftId: shiftId,
      workDate: todayStr,
      checkIn: now,
      status: 'working',
    );

    return await db.insert(_timesheetTable, timesheet.toMap());
  }

  Future<int> checkOut(int timesheetId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    return await db.update(
      _timesheetTable,
      {
        'check_out': now.toIso8601String(),
        'status': 'completed',
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [timesheetId],
    );
  }

  /// Calculate total work hours for an employee in a given month (yyyy-MM).
  /// Returns: { 'total_hours': double, 'total_days': int }
  Future<Map<String, dynamic>> getMonthlyWorkHours(
    int employeeId,
    String month,
  ) async {
    final db = await _dbHelper.database;

    // month format: yyyy-MM
    final startDate = '$month-01';
    // Get last day of the month
    final parts = month.split('-');
    final year = int.parse(parts[0]);
    final mon = int.parse(parts[1]);
    final lastDay = DateTime(year, mon + 1, 0).day;
    final endDate = '$month-${lastDay.toString().padLeft(2, '0')}';

    // Calculate total hours from individual records
    final rows = await db.rawQuery(
      '''
      SELECT check_in, check_out
      FROM $_timesheetTable
      WHERE employee_id = ? 
        AND work_date BETWEEN ? AND ?
        AND status = 'completed'
        AND check_in IS NOT NULL
        AND check_out IS NOT NULL
    ''',
      [employeeId, startDate, endDate],
    );

    double totalHours = 0;
    int totalDays = rows.length;

    for (final row in rows) {
      final checkIn = DateTime.parse(row['check_in'] as String);
      final checkOut = DateTime.parse(row['check_out'] as String);
      final diff = checkOut.difference(checkIn);
      totalHours += diff.inMinutes / 60.0;
    }

    return {
      'total_hours': double.parse(totalHours.toStringAsFixed(1)),
      'total_days': totalDays,
    };
  }
}
