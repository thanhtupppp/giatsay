class Salary {
  final int? id;
  final int employeeId;
  final String month; // Format: 'YYYY-MM'
  final double baseSalary;
  final double bonus;
  final double deduction;
  final double totalSalary;
  final bool paid;
  final DateTime? paidDate;
  final String? notes;
  final DateTime createdAt;

  Salary({
    this.id,
    required this.employeeId,
    required this.month,
    required this.baseSalary,
    this.bonus = 0,
    this.deduction = 0,
    required this.totalSalary,
    this.paid = false,
    this.paidDate,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'month': month,
      'base_salary': baseSalary,
      'bonus': bonus,
      'deduction': deduction,
      'total_salary': totalSalary,
      'paid': paid ? 1 : 0,
      'paid_date': paidDate?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Salary.fromMap(Map<String, dynamic> map) {
    return Salary(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      month: map['month'] as String,
      baseSalary: (map['base_salary'] as num).toDouble(),
      bonus: (map['bonus'] as num).toDouble(),
      deduction: (map['deduction'] as num).toDouble(),
      totalSalary: (map['total_salary'] as num).toDouble(),
      paid: (map['paid'] as int) == 1,
      paidDate: map['paid_date'] != null
          ? DateTime.parse(map['paid_date'] as String)
          : null,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Salary copyWith({
    int? id,
    int? employeeId,
    String? month,
    double? baseSalary,
    double? bonus,
    double? deduction,
    double? totalSalary,
    bool? paid,
    DateTime? paidDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return Salary(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      month: month ?? this.month,
      baseSalary: baseSalary ?? this.baseSalary,
      bonus: bonus ?? this.bonus,
      deduction: deduction ?? this.deduction,
      totalSalary: totalSalary ?? this.totalSalary,
      paid: paid ?? this.paid,
      paidDate: paidDate ?? this.paidDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
