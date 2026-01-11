import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/work_shift.dart';
import '../../models/timesheet.dart';
import '../../repositories/shift_repository.dart';
import '../../core/services/auth_service.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/common_dialogs.dart';

class TimesheetScreen extends StatefulWidget {
  const TimesheetScreen({super.key});

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> with SingleTickerProviderStateMixin {
  final _shiftRepo = ShiftRepository();
  final _currentUser = AuthService.instance.currentUser!;
  
  // State
  bool _isLoading = false;
  Timesheet? _todayTimesheet;
  List<WorkShift> _availableShifts = [];
  List<Timesheet> _myHistory = [];
  WorkShift? _selectedShift;
  
  // Timer for digital clock
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  // Admin State
  List<WorkShift> _allShifts = [];
  List<Timesheet> _allTimesheets = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final isAdmin = AuthService.instance.hasPermission(AppConstants.roleManager);
    _tabController = TabController(length: isAdmin ? 3 : 2, vsync: this);
    
    _loadData();
    _startClock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Get Shifts
      final shifts = await _shiftRepo.getActiveShifts();
      
      // 2. Get Today Status
      final todaySheet = await _shiftRepo.getTodayTimesheet(_currentUser.id!);
      
      // 3. Get History
      final history = await _shiftRepo.getTimesheets(employeeId: _currentUser.id!);

      // 4. Admin Data
      if (AuthService.instance.hasPermission(AppConstants.roleManager)) {
        _allShifts = await _shiftRepo.getAllShifts();
        _allTimesheets = await _shiftRepo.getTimesheets();
      }

      setState(() {
        _availableShifts = shifts;
        _todayTimesheet = todaySheet;
        _myHistory = history;
        // Auto select shift based on current time
        if (_selectedShift == null && shifts.isNotEmpty) {
             _selectedShift = shifts.first; // Simple logic
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) CommonDialogs.showError(context, e);
    }
  }

  Future<void> _checkIn() async {
    if (_selectedShift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ca làm việc')),
      );
      return;
    }

    final confirm = await CommonDialogs.showConfirm(
      context,
      title: 'Xác nhận Check-in',
      content: 'Bắt đầu ca làm việc ${_selectedShift!.name} lúc ${DateFormat('HH:mm').format(DateTime.now())}?',
      confirmText: 'Check-in',
      confirmColor: AppTheme.successColor,
    );

    if (confirm) {
      try {
        await _shiftRepo.checkIn(_currentUser.id!, _selectedShift!.id);
        await _loadData();
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in thành công!'), backgroundColor: AppTheme.successColor));
        }
      } catch (e) {
        if (mounted) CommonDialogs.showError(context, e);
      }
    }
  }

  Future<void> _checkOut() async {
    final confirm = await CommonDialogs.showConfirm(
      context,
      title: 'Xác nhận Check-out',
      content: 'Kết thúc ca làm việc lúc ${DateFormat('HH:mm').format(DateTime.now())}?',
      confirmText: 'Check-out',
      confirmColor: AppTheme.warningColor,
    );

    if (confirm) {
      try {
        await _shiftRepo.checkOut(_todayTimesheet!.id!);
        await _loadData();
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-out thành công!'), backgroundColor: AppTheme.successColor));
        }
      } catch (e) {
        if (mounted) CommonDialogs.showError(context, e);
      }
    }
  }

  // --- Admin Methods ---
  Future<void> _showShiftDialog([WorkShift? shift]) async {
    final nameController = TextEditingController(text: shift?.name ?? '');
    TimeOfDay startTime = shift != null 
        ? TimeOfDay(hour: int.parse(shift.startTime.split(':')[0]), minute: int.parse(shift.startTime.split(':')[1])) 
        : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = shift != null
        ? TimeOfDay(hour: int.parse(shift.endTime.split(':')[0]), minute: int.parse(shift.endTime.split(':')[1]))
        : const TimeOfDay(hour: 17, minute: 0);
        
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
            title: Text(shift == null ? 'Thêm ca làm việc' : 'Sửa ca làm việc'),
            content: Form(
                key: formKey,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: 'Tên ca *'),
                            validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập tên ca' : null,
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Giờ bắt đầu'),
                            trailing: OutlinedButton(
                                onPressed: () async {
                                    final t = await showTimePicker(context: context, initialTime: startTime);
                                    if (t != null) setState(() => startTime = t);
                                },
                                child: Text(startTime.format(context)),
                            ),
                        ),
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Giờ kết thúc'),
                            trailing: OutlinedButton(
                                onPressed: () async {
                                    final t = await showTimePicker(context: context, initialTime: endTime);
                                    if (t != null) setState(() => endTime = t);
                                },
                                child: Text(endTime.format(context)),
                            ),
                        ),
                    ]
                )
            ),
            actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
                ElevatedButton(
                    onPressed: () {
                        if (formKey.currentState!.validate()) {
                            Navigator.pop(context, true);
                        }
                    },
                    child: const Text('Lưu')
                )
            ]
        )
      )
    );
    
    if (result == true) {
        final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
        final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
        
        final newShift = WorkShift(
            id: shift?.id,
            name: nameController.text,
            startTime: startStr,
            endTime: endStr,
            createdAt: shift?.createdAt ?? DateTime.now(),
            updatedAt: DateTime.now(),
        );
        
        try {
            if (shift == null) {
                await _shiftRepo.createShift(newShift);
            } else {
                await _shiftRepo.updateShift(newShift);
            }
            await _loadData();
            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã lưu ca làm việc'), backgroundColor: AppTheme.successColor)
                );
            }
        } catch (e) {
            if (mounted) CommonDialogs.showError(context, e);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthService.instance.hasPermission(AppConstants.roleManager);

    return MainLayout(
      title: 'Chấm công',
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              tabs: [
                const Tab(text: 'Check-in/Out', icon: Icon(Icons.touch_app)),
                const Tab(text: 'Lịch sử', icon: Icon(Icons.history)),
                if (isAdmin) const Tab(text: 'Quản lý Ca', icon: Icon(Icons.settings_suggest)),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    padding: const EdgeInsets.all(16),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTimekeepingTab(),
                        _buildHistoryTab(_myHistory),
                        if (isAdmin) _buildManagerTab(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimekeepingTab() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('EEEE, dd/MM/yyyy', 'vi').format(_currentTime),
                  style: AppTheme.heading3.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                // Digital Clock
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Text(
                    DateFormat('HH:mm:ss').format(_currentTime),
                    style: GoogleFonts.spaceMono(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                
                if (_todayTimesheet == null) ...[
                  // NOT CHECKED IN
                  if (_availableShifts.isEmpty)
                     const Text(
                        'Chưa có ca làm việc nào được cấu hình.',
                        style: TextStyle(color: AppTheme.errorColor, fontSize: 16),
                     ),
                  
                  if (_availableShifts.isNotEmpty) ...[
                      DropdownButtonFormField<WorkShift>(
                        initialValue: _selectedShift,
                        decoration: const InputDecoration(
                          labelText: 'Chọn ca làm việc',
                          prefixIcon: Icon(Icons.work_outline),
                        ),
                        items: _availableShifts.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text('${s.name} (${s.startTime} - ${s.endTime})'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedShift = val),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton.icon(
                          onPressed: _checkIn,
                          icon: const Icon(Icons.login, size: 28),
                          label: const Text('BẮT ĐẦU CA (CHECK-IN)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                  ]
                ] else if (_todayTimesheet!.status == 'working') ...[
                   // WORKING
                   Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: AppTheme.infoColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                          children: [
                              const Icon(Icons.work_history, size: 48, color: AppTheme.infoColor),
                              const SizedBox(height: 16),
                              Text('Đang làm việc: ${_todayTimesheet!.shiftName ?? "Ca tự do"}', 
                                  style: AppTheme.heading3.copyWith(color: AppTheme.infoColor)),
                              const SizedBox(height: 8),
                              Text('Check-in lúc: ${DateFormat('HH:mm').format(_todayTimesheet!.checkIn!)}',
                                  style: AppTheme.bodyLarge),
                          ]
                      )
                   ),
                   const SizedBox(height: 32),
                   SizedBox(
                     width: double.infinity,
                     height: 64,
                     child: ElevatedButton.icon(
                       onPressed: _checkOut,
                       icon: const Icon(Icons.logout, size: 28),
                       label: const Text('KẾT THÚC CA (CHECK-OUT)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppTheme.warningColor,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                       ),
                     ),
                   ),
                ] else ...[
                    // COMPLETED
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle, size: 80, color: AppTheme.successColor),
                    ),
                    const SizedBox(height: 24),
                    Text('Hoàn thành ca làm việc!', style: AppTheme.heading2.copyWith(color: AppTheme.successColor)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         _buildTimeInfo('Check-in', _todayTimesheet!.checkIn!),
                         Container(width: 1, height: 40, color: Colors.grey, margin: const EdgeInsets.symmetric(horizontal: 24)),
                         _buildTimeInfo('Check-out', _todayTimesheet!.checkOut!),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTimeInfo(String label, DateTime time) {
     return Column(
       children: [
         Text(label, style: AppTheme.caption),
         Text(DateFormat('HH:mm').format(time), style: AppTheme.heading3),
       ],
     );
  }

  Widget _buildHistoryTab(List<Timesheet> history) {
    if (history.isEmpty) return const Center(child: Text('Chưa có dữ liệu chấm công'));
    
    return Card(
      child: DataTable2(
          columnSpacing: 12,
          horizontalMargin: 24,
          minWidth: 600,
          headingRowHeight: 56,
          dataRowHeight: 64,
          columns: const [
              DataColumn2(label: Text('Ngày'), size: ColumnSize.M),
              DataColumn2(label: Text('Ca làm việc'), size: ColumnSize.L),
              DataColumn2(label: Text('Giờ vào'), size: ColumnSize.S),
              DataColumn2(label: Text('Giờ ra'), size: ColumnSize.S),
              DataColumn2(label: Text('Trạng thái'), size: ColumnSize.S),
          ],
          rows: history.map((t) => DataRow2(cells: [
              DataCell(Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(t.workDate)), style: const TextStyle(fontWeight: FontWeight.w500))),
              DataCell(Text(t.shiftName ?? '-')),
              DataCell(Text(t.checkIn != null ? DateFormat('HH:mm').format(t.checkIn!) : '--:--')),
              DataCell(Text(t.checkOut != null ? DateFormat('HH:mm').format(t.checkOut!) : '--:--')),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.status == 'completed' ? AppTheme.successColor.withValues(alpha: 0.1) : AppTheme.infoColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: t.status == 'completed' ? AppTheme.successColor : AppTheme.infoColor),
                  ),
                  child: Text(
                    t.status == 'completed' ? 'Hoàn thành' : 'Đang làm',
                    style: TextStyle(
                      color: t.status == 'completed' ? AppTheme.successColor : AppTheme.infoColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ])).toList(),
      ),
    );
  }

  Widget _buildManagerTab() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cấu hình Ca làm việc', style: AppTheme.heading3),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm ca mới'),
                  onPressed: () => _showShiftDialog(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_allShifts.isNotEmpty)
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _allShifts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final s = _allShifts[index];
                    return Card(
                      child: InkWell(
                        onTap: () => _showShiftDialog(s),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 240,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.2),
                                    child: const Icon(Icons.access_time_filled, color: AppTheme.primaryColor),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.name, style: AppTheme.titleMedium, overflow: TextOverflow.ellipsis),
                                        Text(s.isActive ? 'Đang kích hoạt' : 'Đã ẩn', 
                                            style: TextStyle(color: s.isActive ? Colors.green : Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.backgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Text(s.startTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                                    Text(s.endTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Chưa có ca làm việc nào. Hãy thêm ca mới!'),
              ),
              
            const SizedBox(height: 32),
            Text('Lịch sử chấm công toàn bộ nhân viên', style: AppTheme.heading3),
            const SizedBox(height: 16),
            Expanded(child: _buildHistoryTab(_allTimesheets)),
        ]
    );
  }
}
