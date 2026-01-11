import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../models/salary.dart';
import '../../models/user.dart';
import '../../repositories/salary_repository.dart';
import '../../repositories/user_repository.dart';
import '../../config/theme.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/common_dialogs.dart';

class SalaryListScreen extends StatefulWidget {
  const SalaryListScreen({super.key});

  @override
  State<SalaryListScreen> createState() => _SalaryListScreenState();
}

class _SalaryListScreenState extends State<SalaryListScreen> {
  final _salaryRepo = SalaryRepository();
  final _userRepo = UserRepository();
  
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
        if (_selectedMonth != null && s['month'] != _selectedMonth) return false;
        if (_selectedEmployeeId != null && s['employee_id'] != _selectedEmployeeId) return false;
        if (_paidFilter != null) {
          bool isPaid = (s['paid'] as int) == 1;
          if (isPaid != _paidFilter) return false;
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
    String selectedMonth = salaryData?['month'] ?? _selectedMonth ?? DateFormat('yyyy-MM').format(DateTime.now());
    
    final formKey = GlobalKey<FormState>();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(32),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEdit ? 'Sửa lương' : 'Thêm lương mới',
                                style: AppTheme.heading3.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEdit ? 'Cập nhật thông tin lương' : 'Nhập thông tin lương nhân viên',
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Employee dropdown
                    DropdownButtonFormField<int>(
                      initialValue: selectedEmployeeId,
                      decoration: InputDecoration(
                        labelText: 'Nhân viên *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        prefixIcon: const Icon(Icons.person),
                      ),
                      items: _employees.map((emp) {
                        return DropdownMenuItem(
                          value: emp.id,
                          child: Text('${emp.fullName} (${emp.role})'),
                        );
                      }).toList(),
                      onChanged: isEdit ? null : (value) {
                        setState(() {
                          selectedEmployeeId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) return 'Vui lòng chọn nhân viên';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Month picker
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          initialDatePickerMode: DatePickerMode.year,
                        );
                        if (picked != null) {
                          setState(() {
                            selectedMonth = DateFormat('yyyy-MM').format(picked);
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Tháng *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          prefixIcon: const Icon(Icons.calendar_month),
                        ),
                        child: Text(
                          DateFormat('MM/yyyy').format(
                            DateFormat('yyyy-MM').parse(selectedMonth),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Base salary
                    TextFormField(
                      controller: baseSalaryController,
                      decoration: InputDecoration(
                        labelText: 'Lương cơ bản *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        suffixText: 'đ',
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập lương cơ bản';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Số tiền không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        // Bonus
                        Expanded(
                          child: TextFormField(
                            controller: bonusController,
                            decoration: InputDecoration(
                              labelText: 'Thưởng',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              suffixText: 'đ',
                              prefixIcon: Icon(Icons.add_circle, color: AppTheme.successColor),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Deductions
                        Expanded(
                          child: TextFormField(
                            controller: deductionsController,
                            decoration: InputDecoration(
                              labelText: 'Khấu trừ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              suffixText: 'đ',
                              prefixIcon: Icon(Icons.remove_circle, color: AppTheme.errorColor),
                            ),
                            keyboardType: TextInputType.number,
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
                            NumberFormat.currency(locale: 'vi', symbol: 'đ').format(
                              (double.tryParse(baseSalaryController.text) ?? 0) +
                              (double.tryParse(bonusController.text) ?? 0) -
                              (double.tryParse(deductionsController.text) ?? 0),
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
                    
                    // Notes
                    TextFormField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Hủy', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                Navigator.of(context).pop(true);
                              }
                            },
                            icon: const Icon(Icons.check),
                            label: Text(
                              isEdit ? 'Cập nhật' : 'Thêm',
                              style: const TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
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
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
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
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(isEdit ? 'Đã cập nhật lương' : 'Đã thêm lương mới'),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
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
    try {
      await _salaryRepo.markAsPaid(salaryId);
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Đã đánh dấu đã trả'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
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
  
  Future<void> _deleteSalary(int salaryId) async {
    final confirm = await CommonDialogs.showDeleteConfirmation(
      context,
      title: 'Xóa lương',
      content: 'Bạn có chắc chắn muốn xóa bản ghi lương này? Hành động này không thể hoàn tác.',
    );
    
    if (confirm) {
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
    return MainLayout(
      title: 'Quản lý lương nhân viên',
      child: Column(
        children: [
          // Filters and stats
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Stats cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Tổng lương',
                        NumberFormat.currency(locale: 'vi', symbol: 'đ').format(_totalSalaries),
                        Icons.account_balance_wallet,
                        AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Đã trả',
                        _paidCount.toString(),
                        Icons.check_circle,
                        AppTheme.successColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Chưa trả',
                        _unpaidCount.toString(),
                        Icons.pending,
                        AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Filters
                Row(
                  children: [
                    // Month filter
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
                              _selectedMonth = DateFormat('yyyy-MM').format(picked);
                            });
                            _loadData();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tháng',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_month),
                          ),
                          child: Text(
                            _selectedMonth != null
                                ? DateFormat('MM/yyyy').format(
                                    DateFormat('yyyy-MM').parse(_selectedMonth!),
                                  )
                                : 'Tất cả',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Employee filter
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        initialValue: _selectedEmployeeId,
                        decoration: const InputDecoration(
                          labelText: 'Nhân viên',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả'),
                          ),
                          ..._employees.map((emp) {
                            return DropdownMenuItem(
                              value: emp.id,
                              child: Text(emp.fullName),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedEmployeeId = value;
                          });
                          _loadData();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Payment status filter
                    Expanded(
                      child: DropdownButtonFormField<bool?>(
                        initialValue: _paidFilter,
                        decoration: const InputDecoration(
                          labelText: 'Trạng thái',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.paid),
                        ),
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
                        onChanged: (value) {
                          setState(() {
                            _paidFilter = value;
                          });
                          _loadData();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm lương'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Data table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _salaries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 64,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có bản ghi lương nào',
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : DataTable2(
                        columnSpacing: 12,
                        horizontalMargin: 12,
                        minWidth: 900,
                        columns: const [
                          DataColumn2(
                            label: Text('Nhân viên'),
                            size: ColumnSize.L,
                          ),
                          DataColumn2(
                            label: Text('Tháng'),
                            size: ColumnSize.S,
                          ),
                          DataColumn2(
                            label: Text('Lương CB'),
                            size: ColumnSize.M,
                          ),
                          DataColumn2(
                            label: Text('Thưởng'),
                            size: ColumnSize.S,
                          ),
                          DataColumn2(
                            label: Text('Khấu trừ'),
                            size: ColumnSize.S,
                          ),
                          DataColumn2(
                            label: Text('Tổng'),
                            size: ColumnSize.M,
                          ),
                          DataColumn2(
                            label: Text('Trạng thái'),
                            size: ColumnSize.S,
                          ),
                          DataColumn2(
                            label: Text('Thao tác'),
                            size: ColumnSize.M,
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
                                      style: const TextStyle(fontWeight: FontWeight.w600),
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
                                    DateFormat('yyyy-MM').parse(salary['month'] as String),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  NumberFormat.compact(locale: 'vi').format(salary['base_salary']),
                                ),
                              ),
                              DataCell(
                                Text(
                                  NumberFormat.compact(locale: 'vi').format(salary['bonus']),
                                  style: TextStyle(color: AppTheme.successColor),
                                ),
                              ),
                              DataCell(
                                Text(
                                  NumberFormat.compact(locale: 'vi').format(salary['deduction']),
                                  style: TextStyle(color: AppTheme.errorColor),
                                ),
                              ),
                              DataCell(
                                Text(
                                  NumberFormat.currency(locale: 'vi', symbol: 'đ')
                                      .format(salary['total_salary']),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (isPaid ? AppTheme.successColor : AppTheme.warningColor)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isPaid ? AppTheme.successColor : AppTheme.warningColor,
                                    ),
                                  ),
                                  child: Text(
                                    isPaid ? 'Đã trả' : 'Chưa trả',
                                    style: TextStyle(
                                      color: isPaid ? AppTheme.successColor : AppTheme.warningColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
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
                                        icon: const Icon(Icons.check),
                                        iconSize: 20,
                                        color: AppTheme.successColor,
                                        onPressed: () => _markAsPaid(salary['id'] as int),
                                        tooltip: 'Đánh dấu đã trả',
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      iconSize: 20,
                                      onPressed: () => _showAddEditDialog(salary),
                                      tooltip: 'Sửa',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      iconSize: 20,
                                      color: AppTheme.errorColor,
                                      onPressed: () => _deleteSalary(salary['id'] as int),
                                      tooltip: 'Xóa',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
