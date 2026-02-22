import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../models/salary.dart';
import '../../models/user.dart';
import '../../repositories/salary_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/shift_repository.dart';
import '../../config/theme.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/inputs.dart';
import '../../widgets/ui/dialogs.dart';

class SalaryListScreen extends StatefulWidget {
  const SalaryListScreen({super.key});

  @override
  State<SalaryListScreen> createState() => _SalaryListScreenState();
}

class _SalaryListScreenState extends State<SalaryListScreen> {
  final _salaryRepo = SalaryRepository();
  final _userRepo = UserRepository();
  final _shiftRepo = ShiftRepository();

  List<Map<String, dynamic>> _salaries = [];
  List<User> _employees = [];
  bool _isLoading = true;

  String? _selectedMonth;
  int? _selectedEmployeeId;
  bool? _paidFilter;

  double _totalSalaries = 0;
  int _paidCount = 0;
  int _unpaidCount = 0;

  @override
  void initState() {
    super.initState();
    // Default to current month
    _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final employees = await _userRepo.getAll();
      final salaries = await _salaryRepo.getSalaryByEmployeeWithName();

      // Apply filters
      var filteredSalaries = salaries.where((s) {
        if (_selectedMonth != null && s['month'] != _selectedMonth) {
          return false;
        }
        if (_selectedEmployeeId != null &&
            s['employee_id'] != _selectedEmployeeId) {
          return false;
        }
        if (_paidFilter != null) {
          bool isPaid = (s['paid'] as int) == 1;
          if (isPaid != _paidFilter) {
            return false;
          }
        }
        return true;
      }).toList();

      // Calculate stats
      double total = 0;
      int paid = 0;
      int unpaid = 0;

      for (final salary in filteredSalaries) {
        total += (salary['total_salary'] as num).toDouble();
        if ((salary['paid'] as int) == 1) {
          paid++;
        } else {
          unpaid++;
        }
      }

      setState(() {
        _employees = employees;
        _salaries = filteredSalaries;
        _totalSalaries = total;
        _paidCount = paid;
        _unpaidCount = unpaid;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showAddEditDialog([Map<String, dynamic>? salaryData]) async {
    final isEdit = salaryData != null;

    final baseSalaryController = TextEditingController(
      text: salaryData?['base_salary']?.toString() ?? '',
    );
    final bonusController = TextEditingController(
      text: salaryData?['bonus']?.toString() ?? '0',
    );
    final deductionsController = TextEditingController(
      text: salaryData?['deduction']?.toString() ?? '0',
    );
    final notesController = TextEditingController(
      text: salaryData?['notes'] ?? '',
    );

    int? selectedEmployeeId = salaryData?['employee_id'];
    String selectedMonth =
        salaryData?['month'] ??
        _selectedMonth ??
        DateFormat('yyyy-MM').format(DateTime.now());

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(32),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? 'Sửa lương' : 'Thêm lương mới',
                      style: AppTheme.heading2,
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: AppDropdown<int>(
                            label: 'Nhân viên',
                            value: selectedEmployeeId,
                            items: _employees.map((emp) {
                              return DropdownMenuItem(
                                value: emp.id,
                                child: Text('${emp.fullName} (${emp.role})'),
                              );
                            }).toList(),
                            onChanged: isEdit
                                ? null
                                : (value) {
                                    setState(() {
                                      selectedEmployeeId = value;
                                    });
                                  },
                            validator: (value) {
                              if (value == null) {
                                return 'Vui lòng chọn nhân viên';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateFormat(
                                  'yyyy-MM',
                                ).parse(selectedMonth),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                initialDatePickerMode: DatePickerMode.year,
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedMonth = DateFormat(
                                    'yyyy-MM',
                                  ).format(picked);
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Tháng *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_month),
                              ),
                              child: Text(
                                DateFormat('MM/yyyy').format(
                                  DateFormat('yyyy-MM').parse(selectedMonth),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Auto-calculate from timesheets
                    if (!isEdit)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: OutlinedButton.icon(
                          onPressed: selectedEmployeeId == null
                              ? null
                              : () async {
                                  try {
                                    final workData = await _shiftRepo
                                        .getMonthlyWorkHours(
                                          selectedEmployeeId!,
                                          selectedMonth,
                                        );
                                    final totalHours =
                                        (workData['total_hours'] as double);
                                    final totalDays =
                                        (workData['total_days'] as int);

                                    if (totalDays == 0) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Không tìm thấy dữ liệu chấm công trong tháng này',
                                            ),
                                            backgroundColor:
                                                AppTheme.warningColor,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    // Calculate: hourlyRate = 25,000đ/hour
                                    const hourlyRate = 25000.0;
                                    final calculatedSalary =
                                        totalHours * hourlyRate;

                                    setState(() {
                                      baseSalaryController.text =
                                          calculatedSalary.toStringAsFixed(0);
                                    });

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Đã tính: $totalDays ngày, ${totalHours.toStringAsFixed(1)}h × 25.000đ = ${NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0).format(calculatedSalary)}',
                                          ),
                                          backgroundColor:
                                              AppTheme.successColor,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Lỗi tính lương: $e'),
                                          backgroundColor: AppTheme.errorColor,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.calculate, size: 18),
                          label: const Text('Tự tính từ chấm công'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: BorderSide(color: AppTheme.primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                    AppNumberField(
                      controller: baseSalaryController,
                      label: 'Lương cơ bản',
                      suffixText: 'đ',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập lương cơ bản';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: AppNumberField(
                            controller: bonusController,
                            label: 'Thưởng',
                            suffixText: 'đ',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppNumberField(
                            controller: deductionsController,
                            label: 'Khấu trừ',
                            suffixText: 'đ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Total display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tổng lương:',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            NumberFormat.currency(
                              locale: 'vi',
                              symbol: 'đ',
                            ).format(
                              (double.tryParse(baseSalaryController.text) ??
                                      0) +
                                  (double.tryParse(bonusController.text) ?? 0) -
                                  (double.tryParse(deductionsController.text) ??
                                      0),
                            ),
                            style: AppTheme.heading3.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      controller: notesController,
                      label: 'Ghi chú',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SecondaryButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          label: 'Hủy',
                        ),
                        const SizedBox(width: 16),
                        PrimaryButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.of(context).pop(true);
                            }
                          },
                          label: isEdit ? 'Cập nhật' : 'Thêm',
                          icon: Icons.check,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (result == true && selectedEmployeeId != null) {
      try {
        final baseSalary = double.parse(baseSalaryController.text);
        final bonus = double.tryParse(bonusController.text) ?? 0;
        final deductions = double.tryParse(deductionsController.text) ?? 0;

        final salary = Salary(
          id: salaryData?['id'],
          employeeId: selectedEmployeeId!,
          month: selectedMonth,
          baseSalary: baseSalary,
          bonus: bonus,
          deduction: deductions,
          totalSalary: baseSalary + bonus - deductions,
          paid: false,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        );

        if (isEdit) {
          await _salaryRepo.update(salary);
        } else {
          await _salaryRepo.create(salary);
        }

        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit ? 'Đã cập nhật lương' : 'Đã thêm lương mới'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }

    baseSalaryController.dispose();
    bonusController.dispose();
    deductionsController.dispose();
    notesController.dispose();
  }

  Future<void> _markAsPaid(int salaryId) async {
    final confirm = await showAppConfirmDialog(
      context,
      title: 'Xác nhận thanh toán',
      content: 'Bạn có chắc chắn muốn đánh dấu đã thanh toán lương này không?',
      confirmText: 'Xác nhận',
      confirmColor: AppTheme.successColor,
    );

    if (confirm == true) {
      try {
        await _salaryRepo.markAsPaid(salaryId);
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã đánh dấu đã trả'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteSalary(int salaryId) async {
    final confirm = await showAppConfirmDialog(
      context,
      title: 'Xóa lương',
      content:
          'Bạn có chắc chắn muốn xóa bản ghi lương này? Hành động này không thể hoàn tác.',
      confirmText: 'Xóa',
      confirmColor: AppTheme.errorColor,
    );

    if (confirm == true) {
      try {
        await _salaryRepo.delete(salaryId);
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa bản ghi lương'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi xóa: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      title: 'Quản lý lương nhân viên',
      actions: [
        PrimaryButton(
          onPressed: () => _showAddEditDialog(),
          icon: Icons.add,
          label: 'Thêm lương',
        ),
      ],
      child: Column(
        children: [
          // Filters and stats
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          'Tổng lương',
                          NumberFormat.currency(
                            locale: 'vi',
                            symbol: 'đ',
                          ).format(_totalSalaries),
                          Icons.account_balance_wallet,
                          AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem(
                          'Đã trả',
                          _paidCount.toString(),
                          Icons.check_circle,
                          AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatItem(
                          'Chưa trả',
                          _unpaidCount.toString(),
                          Icons.pending,
                          AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedMonth != null
                                  ? DateFormat('yyyy-MM').parse(_selectedMonth!)
                                  : DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              initialDatePickerMode: DatePickerMode.year,
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedMonth = DateFormat(
                                  'yyyy-MM',
                                ).format(picked);
                              });
                              _loadData();
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tháng',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_month),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              _selectedMonth != null
                                  ? DateFormat('MM/yyyy').format(
                                      DateFormat(
                                        'yyyy-MM',
                                      ).parse(_selectedMonth!),
                                    )
                                  : 'Tất cả',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppDropdown<int?>(
                          label: 'Nhân viên',
                          value: _selectedEmployeeId,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Tất cả'),
                            ),
                            ..._employees.map(
                              (e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(e.fullName),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedEmployeeId = v);
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppDropdown<bool?>(
                          label: 'Trạng thái',
                          value: _paidFilter,
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text('Tất cả'),
                            ),
                            DropdownMenuItem(
                              value: true,
                              child: Text('Đã trả'),
                            ),
                            DropdownMenuItem(
                              value: false,
                              child: Text('Chưa trả'),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() => _paidFilter = v);
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Data table
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _salaries.isEmpty
                  ? const Center(child: Text('Chưa có bản ghi lương nào'))
                  : DataTable2(
                      columnSpacing: 12,
                      horizontalMargin: 20,
                      minWidth: 900,
                      headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                      columns: const [
                        DataColumn2(
                          label: Text(
                            'Nhân viên',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.L,
                        ),
                        DataColumn2(
                          label: Text(
                            'Tháng',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                        ),
                        DataColumn2(
                          label: Text(
                            'Lương CB',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                          numeric: true,
                        ),
                        DataColumn2(
                          label: Text(
                            'Thưởng',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                          numeric: true,
                        ),
                        DataColumn2(
                          label: Text(
                            'Khấu trừ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                          numeric: true,
                        ),
                        DataColumn2(
                          label: Text(
                            'Tổng',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                          numeric: true,
                        ),
                        DataColumn2(
                          label: Text(
                            'Trạng thái',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                        ),
                        DataColumn2(
                          label: Text(
                            'Thao tác',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                        ),
                      ],
                      rows: _salaries.map((salary) {
                        final isPaid = (salary['paid'] as int) == 1;

                        return DataRow2(
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    salary['employee_name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    salary['employee_role'] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                DateFormat('MM/yyyy').format(
                                  DateFormat(
                                    'yyyy-MM',
                                  ).parse(salary['month'] as String),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                NumberFormat.compact(
                                  locale: 'vi',
                                ).format(salary['base_salary']),
                              ),
                            ),
                            DataCell(
                              Text(
                                NumberFormat.compact(
                                  locale: 'vi',
                                ).format(salary['bonus']),
                                style: TextStyle(color: AppTheme.successColor),
                              ),
                            ),
                            DataCell(
                              Text(
                                NumberFormat.compact(
                                  locale: 'vi',
                                ).format(salary['deduction']),
                                style: TextStyle(color: AppTheme.errorColor),
                              ),
                            ),
                            DataCell(
                              Text(
                                NumberFormat.currency(
                                  locale: 'vi',
                                  symbol: 'đ',
                                ).format(salary['total_salary']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? AppTheme.successColor.withValues(
                                          alpha: 0.1,
                                        )
                                      : AppTheme.warningColor.withValues(
                                          alpha: 0.1,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isPaid ? 'Đã trả' : 'Chưa trả',
                                  style: TextStyle(
                                    color: isPaid
                                        ? AppTheme.successColor
                                        : AppTheme.warningColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isPaid)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.green,
                                      ),
                                      tooltip: 'Đánh dấu đã trả',
                                      onPressed: () =>
                                          _markAsPaid(salary['id']),
                                    ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _showAddEditDialog(salary),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        _deleteSalary(salary['id']),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}
