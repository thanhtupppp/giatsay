import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../core/services/auth_service.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/user_repository.dart';
import '../../models/user.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';
import '../../widgets/ui/buttons.dart';
import '../../core/services/print_service.dart';

class ShiftReportScreen extends StatefulWidget {
  const ShiftReportScreen({super.key});

  @override
  State<ShiftReportScreen> createState() => _ShiftReportScreenState();
}

class _ShiftReportScreenState extends State<ShiftReportScreen> {
  final _orderRepo = OrderRepository();
  final _userRepo = UserRepository();

  DateTime _selectedDate = DateTime.now();
  int? _selectedEmployeeId;
  bool _isAdmin = false;
  List<User> _employees = [];

  List<Map<String, dynamic>> _orderDetails = [];
  bool _isLoading = true;

  // Aggregated values
  double _totalCash = 0;
  double _totalTransfer = 0;
  double _totalEWallet = 0;
  double _totalAll = 0;
  int _totalOrders = 0;
  double _totalUnpaid = 0;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final isAdmin = AuthService.instance.hasPermission(AppConstants.roleAdmin);

    setState(() {
      _isAdmin = isAdmin;
    });

    if (isAdmin) {
      final employees = await _userRepo.getAll(activeOnly: true);
      setState(() {
        _employees = employees;
      });
    } else {
      _selectedEmployeeId = user.id;
    }

    await _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final revenue = await _orderRepo.getShiftRevenue(
        date: _selectedDate,
        employeeId: _selectedEmployeeId,
      );

      final orders = await _orderRepo.getShiftOrderDetails(
        date: _selectedDate,
        employeeId: _selectedEmployeeId,
      );

      // Aggregate by payment method
      double cash = 0, transfer = 0, eWallet = 0, total = 0, unpaid = 0;
      int orderCount = 0;

      for (final row in revenue) {
        final paid = (row['total_paid'] as num).toDouble();
        final method = row['payment_method'] as String?;
        final count = (row['order_count'] as num).toInt();

        orderCount += count;
        total += paid;

        switch (method) {
          case 'cash':
            cash += paid;
            break;
          case 'bank_transfer':
            transfer += paid;
            break;
          case 'momo':
          case 'zalopay':
            eWallet += paid;
            break;
          default:
            cash += paid; // Default unspecified to cash
        }
      }

      // Calculate unpaid
      for (final order in orders) {
        final orderTotal = (order['total_amount'] as num).toDouble();
        final orderPaid = (order['paid_amount'] as num).toDouble();
        if (orderPaid < orderTotal) {
          unpaid += (orderTotal - orderPaid);
        }
      }

      setState(() {
        _orderDetails = orders;
        _totalCash = cash;
        _totalTransfer = transfer;
        _totalEWallet = eWallet;
        _totalAll = total;
        _totalOrders = orderCount;
        _totalUnpaid = unpaid;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải báo cáo: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadReport();
    }
  }

  Future<void> _printReport() async {
    try {
      final user = AuthService.instance.currentUser;
      final employeeName = _selectedEmployeeId != null
          ? _employees
                .where((e) => e.id == _selectedEmployeeId)
                .map((e) => e.fullName)
                .firstOrNull
          : null;

      await PrintService.instance.printShiftReport(
        date: _selectedDate,
        employeeName: employeeName ?? user?.fullName ?? 'N/A',
        cashTotal: _totalCash,
        transferTotal: _totalTransfer,
        eWalletTotal: _totalEWallet,
        grandTotal: _totalAll,
        orderCount: _totalOrders,
        unpaidTotal: _totalUnpaid,
        orders: _orderDetails,
        isAllEmployees: _selectedEmployeeId == null && _isAdmin,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã gửi in báo cáo'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi in báo cáo: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi', symbol: 'đ').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      title: 'Báo cáo doanh thu ca',
      actions: [
        PrimaryButton(
          onPressed: _printReport,
          icon: Icons.print,
          label: 'In báo cáo',
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filters
                _buildFilters(),
                const SizedBox(height: 16),

                // Summary Cards
                _buildSummaryCards(),
                const SizedBox(height: 16),

                // Detail Table
                Expanded(child: _buildOrderTable()),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Date Picker
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ngày báo cáo', style: AppTheme.caption),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat(
                            'dd/MM/yyyy (EEEE)',
                            'vi',
                          ).format(_selectedDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Quick date buttons
          const SizedBox(width: 12),
          _buildQuickDateButton('Hôm nay', DateTime.now()),
          const SizedBox(width: 8),
          _buildQuickDateButton(
            'Hôm qua',
            DateTime.now().subtract(const Duration(days: 1)),
          ),

          // Employee filter (Admin only)
          if (_isAdmin) ...[
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int?>(
                // ignore: deprecated_member_use
                value: _selectedEmployeeId,
                decoration: InputDecoration(
                  labelText: 'Nhân viên',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Tất cả nhân viên'),
                  ),
                  ..._employees.map(
                    (emp) => DropdownMenuItem<int?>(
                      value: emp.id,
                      child: Text(emp.fullName),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedEmployeeId = value);
                  _loadReport();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickDateButton(String label, DateTime date) {
    final isSelected =
        DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(date);
    return OutlinedButton(
      onPressed: () {
        setState(() => _selectedDate = date);
        _loadReport();
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : null,
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildRevenueCard(
            icon: Icons.payments_outlined,
            title: 'Tiền mặt',
            amount: _totalCash,
            color: const Color(0xFF2E7D32),
            bgColor: const Color(0xFFE8F5E9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRevenueCard(
            icon: Icons.account_balance_outlined,
            title: 'Chuyển khoản',
            amount: _totalTransfer,
            color: const Color(0xFF1565C0),
            bgColor: const Color(0xFFE3F2FD),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRevenueCard(
            icon: Icons.phone_android,
            title: 'Ví điện tử',
            amount: _totalEWallet,
            color: const Color(0xFF7B1FA2),
            bgColor: const Color(0xFFF3E5F5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRevenueCard(
            icon: Icons.account_balance_wallet,
            title: 'Tổng thu',
            amount: _totalAll,
            color: AppTheme.primaryColor,
            bgColor: const Color(0xFFE8EAF6),
            isHighlighted: true,
            subtitle: '$_totalOrders đơn hàng',
          ),
        ),
        if (_totalUnpaid > 0) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildRevenueCard(
              icon: Icons.warning_amber_outlined,
              title: 'Chưa thanh toán',
              amount: _totalUnpaid,
              color: AppTheme.warningColor,
              bgColor: const Color(0xFFFFF3E0),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRevenueCard({
    required IconData icon,
    required String title,
    required double amount,
    required Color color,
    required Color bgColor,
    bool isHighlighted = false,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? color.withValues(alpha: 0.3)
              : AppTheme.borderColor.withValues(alpha: 0.5),
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatCurrency(amount),
              style: TextStyle(
                fontSize: isHighlighted ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: isHighlighted ? color : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTable() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: AppTheme.primaryColor, size: 22),
                const SizedBox(width: 8),
                Text('Chi tiết đơn hàng', style: AppTheme.heading3),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_orderDetails.length} đơn',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _orderDetails.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không có đơn hàng nào trong ngày này',
                          style: AppTheme.bodyLarge.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: DataTable2(
                      columnSpacing: 16,
                      horizontalMargin: 20,
                      minWidth: 900,
                      dataRowHeight: 56,
                      headingRowHeight: 48,
                      headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                      columns: [
                        const DataColumn2(
                          label: Text(
                            'MÃ ĐƠN',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                        ),
                        const DataColumn2(
                          label: Text(
                            'KHÁCH HÀNG',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.L,
                        ),
                        if (_isAdmin && _selectedEmployeeId == null)
                          const DataColumn2(
                            label: Text(
                              'NHÂN VIÊN',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            size: ColumnSize.M,
                          ),
                        const DataColumn2(
                          label: Text(
                            'THANH TOÁN',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                        ),
                        const DataColumn2(
                          label: Text(
                            'TỔNG TIỀN',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                          numeric: true,
                        ),
                        const DataColumn2(
                          label: Text(
                            'ĐÃ THU',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                          numeric: true,
                        ),
                        const DataColumn2(
                          label: Text(
                            'TRẠNG THÁI',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                        ),
                      ],
                      rows: _orderDetails.map((order) {
                        final status = order['status'] as String;
                        final statusColor = AppTheme.getStatusColor(status);
                        final paymentMethod =
                            order['payment_method'] as String?;
                        final totalAmount = (order['total_amount'] as num)
                            .toDouble();
                        final paidAmount = (order['paid_amount'] as num)
                            .toDouble();
                        final isPaid = paidAmount >= totalAmount;

                        return DataRow2(
                          cells: [
                            DataCell(
                              Text(
                                order['order_code'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order['customer_name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    order['customer_phone'] as String,
                                    style: AppTheme.caption,
                                  ),
                                ],
                              ),
                            ),
                            if (_isAdmin && _selectedEmployeeId == null)
                              DataCell(
                                Text(
                                  (order['employee_name'] as String?) ?? 'N/A',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            DataCell(_buildPaymentBadge(paymentMethod)),
                            DataCell(
                              Text(
                                _formatCurrency(totalAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _formatCurrency(paidAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isPaid
                                      ? AppTheme.successColor
                                      : AppTheme.warningColor,
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
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  AppConstants.orderStatusLabels[status] ??
                                      status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),

          // Footer totals
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                _buildFooterItem(
                  Icons.receipt_long,
                  '$_totalOrders đơn',
                  AppTheme.textSecondary,
                ),
                const SizedBox(width: 24),
                _buildFooterItem(
                  Icons.payments,
                  _formatCurrency(_totalCash),
                  const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 24),
                _buildFooterItem(
                  Icons.account_balance,
                  _formatCurrency(_totalTransfer),
                  const Color(0xFF1565C0),
                ),
                const SizedBox(width: 24),
                _buildFooterItem(
                  Icons.phone_android,
                  _formatCurrency(_totalEWallet),
                  const Color(0xFF7B1FA2),
                ),
                const Spacer(),
                Text('Tổng thu: ', style: AppTheme.bodyLarge),
                Text(
                  _formatCurrency(_totalAll),
                  style: AppTheme.heading3.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentBadge(String? method) {
    final label = AppConstants.paymentMethodLabels[method] ?? 'Chưa TT';
    Color color;
    IconData icon;

    switch (method) {
      case 'cash':
        color = const Color(0xFF2E7D32);
        icon = Icons.payments_outlined;
        break;
      case 'bank_transfer':
        color = const Color(0xFF1565C0);
        icon = Icons.account_balance_outlined;
        break;
      case 'momo':
        color = const Color(0xFFD81B60);
        icon = Icons.phone_android;
        break;
      case 'zalopay':
        color = const Color(0xFF0277BD);
        icon = Icons.phone_android;
        break;
      default:
        color = AppTheme.textSecondary;
        icon = Icons.help_outline;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
