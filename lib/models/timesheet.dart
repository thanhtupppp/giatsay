class Timesheet {
  final int? id;
  final int employeeId;
  final int? shiftId;
  final String workDate;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final String? notes;
  
  // UI Helpers
  final String? employeeName;
  final String? shiftName;

  Timesheet({
    this.id,
    required this.employeeId,
    this.shiftId,
    required this.workDate,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.notes,
    this.employeeName,
    this.shiftName,
  });

  Timesheet copyWith({
    int? id,
    int? employeeId,
    int? shiftId,
    String? workDate,
    DateTime? checkIn,
    DateTime? checkOut,
    String? status,
    String? notes,
    String? employeeName,
    String? shiftName,
  }) {
    return Timesheet(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      shiftId: shiftId ?? this.shiftId,
      workDate: workDate ?? this.workDate,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      employeeName: employeeName ?? this.employeeName,
      shiftName: shiftName ?? this.shiftName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'shift_id': shiftId,
      'work_date': workDate,
      'check_in': checkIn?.toIso8601String(),
      'check_out': checkOut?.toIso8601String(),
      'status': status,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory Timesheet.fromMap(Map<String, dynamic> map) {
    return Timesheet(
      id: map['id'],
      employeeId: map['employee_id'],
      shiftId: map['shift_id'],
      workDate: map['work_date'],
      checkIn: map['check_in'] != null ? DateTime.parse(map['check_in']) : null,
      checkOut: map['check_out'] != null ? DateTime.parse(map['check_out']) : null,
      status: map['status'],
      notes: map['notes'],
      employeeName: map['employee_name'],
      shiftName: map['shift_name'],
    );
  }
}
