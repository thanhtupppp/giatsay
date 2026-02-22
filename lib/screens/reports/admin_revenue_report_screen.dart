import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../repositories/order_repository.dart';
import '../../config/theme.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';

class AdminRevenueReportScreen extends StatefulWidget {
  const AdminRevenueReportScreen({super.key});

  @override
  State<AdminRevenueReportScreen> createState() =>
      _AdminRevenueReportScreenState();
}

class _AdminRevenueReportScreenState extends State<AdminRevenueReportScreen> {
  final _orderRepo = OrderRepository();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = true;

  List<Map<String, dynamic>> _employeeData = [];
  // Totals
  double _grandTotal = 0;
  double _grandPaid = 0;
  double _grandCash = 0;
  double _grandTransfer = 0;
  double _grandEWallet = 0;
  int _grandOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final data = await _orderRepo.getEmployeeRevenueReport(
        startDate: _startDate,
        endDate: _endDate,
      );

      double total = 0, paid = 0, cash = 0, transfer = 0, eWallet = 0;
      int orders = 0;

      for (final row in data) {
        total += (row['total_amount'] as num).toDouble();
        paid += (row['total_paid'] as num).toDouble();
        cash += (row['cash_amount'] as num).toDouble();
        transfer += (row['transfer_amount'] as num).toDouble();
        eWallet += (row['ewallet_amount'] as num).toDouble();
        orders += (row['order_count'] as num).toInt();
      }

      setState(() {
        _employeeData = data;
        _grandTotal = total;
        _grandPaid = paid;
        _grandCash = cash;
        _grandTransfer = transfer;
        _grandEWallet = eWallet;
        _grandOrders = orders;
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

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReport();
    }
  }

  String _fmt(double amount) {
    return NumberFormat.currency(locale: 'vi', symbol: 'đ').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      title: 'Báo cáo doanh số',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilters(),
                const SizedBox(height: 16),
                _buildSummaryCards(),
                const SizedBox(height: 16),
                Expanded(child: _buildEmployeeTable()),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Date Range
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: _pickDateRange,
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
                      Icons.date_range,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Khoảng thời gian', style: AppTheme.caption),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(_startDate)} → ${DateFormat('dd/MM/yyyy').format(_endDate)}',
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
          const SizedBox(width: 12),
          _buildQuickRange('7 ngày', 7),
          const SizedBox(width: 8),
          _buildQuickRange('30 ngày', 30),
          const SizedBox(width: 8),
          _buildQuickRange('Tháng này', -1),
        ],
      ),
    );
  }

  Widget _buildQuickRange(String label, int days) {
    DateTime start;
    DateTime end = DateTime.now();

    if (days == -1) {
      // This month
      start = DateTime(end.year, end.month, 1);
    } else {
      start = end.subtract(Duration(days: days));
    }

    final isSelected =
        DateFormat('yyyy-MM-dd').format(_startDate) ==
            DateFormat('yyyy-MM-dd').format(start) &&
        DateFormat('yyyy-MM-dd').format(_endDate) ==
            DateFormat('yyyy-MM-dd').format(end);

    return OutlinedButton(
      onPressed: () {
        setState(() {
          _startDate = start;
          _endDate = end;
        });
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
    final unpaid = _grandTotal - _grandPaid;
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Tổng doanh số',
            value: _fmt(_grandTotal),
            icon: Icons.trending_up,
            color: AppTheme.primaryColor,
            subValue: '$_grandOrders đơn hàng',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: 'Đã thu',
            value: _fmt(_grandPaid),
            icon: Icons.account_balance_wallet,
            color: AppTheme.successColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: 'Tiền mặt',
            value: _fmt(_grandCash),
            icon: Icons.payments_outlined,
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: 'Chuyển khoản',
            value: _fmt(_grandTransfer),
            icon: Icons.account_balance_outlined,
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: 'Ví điện tử',
            value: _fmt(_grandEWallet),
            icon: Icons.phone_android,
            color: const Color(0xFF7B1FA2),
          ),
        ),
        if (unpaid > 0) ...[
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              title: 'Chưa thu',
              value: _fmt(unpaid),
              icon: Icons.warning_amber,
              color: AppTheme.warningColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmployeeTable() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Icon(Icons.people, color: AppTheme.primaryColor, size: 22),
                const SizedBox(width: 8),
                Text('Doanh số theo nhân viên', style: AppTheme.heading3),
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
                    '${_employeeData.length} nhân viên',
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
            child: _employeeData.isEmpty
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
                          'Không có dữ liệu trong khoảng thời gian này',
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
                      dataRowHeight: 64,
                      headingRowHeight: 48,
                      headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                      columns: const [
                        DataColumn2(
                          label: Text(
                            'NHÂN VIÊN',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.L,
                        ),
                        DataColumn2(
                          label: Text(
                            'SỐ ĐƠN',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                          numeric: true,
                        ),
                        DataColumn2(
                          label: Text(
                            'DOANH SỐ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                          numeric: true,
                        ),
                        DataColumn2(
                          label: Text(
                            'ĐÃ THU',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                          numeric: true,
                        ),
                        DataColumn2(
                          label: Text(
                            'TIỀN MẶT',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                          numeric: true,
                        ),
                        DataColumn2(
                          label: Text(
                            'CK',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                          numeric: true,
                        ),
                        DataColumn2(
                          label: Text(
                            'VÍ ĐT',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                          numeric: true,
                        ),
                        DataColumn2(
                          label: Text(
                            'TỶ LỆ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                        ),
                      ],
                      rows: _employeeData.map((emp) {
                        final totalPaid = (emp['total_paid'] as num).toDouble();
                        final totalAmount = (emp['total_amount'] as num)
                            .toDouble();
                        final cash = (emp['cash_amount'] as num).toDouble();
                        final transfer = (emp['transfer_amount'] as num)
                            .toDouble();
                        final eWallet = (emp['ewallet_amount'] as num)
                            .toDouble();
                        final orderCount = (emp['order_count'] as num).toInt();
                        final percentage = _grandPaid > 0
                            ? (totalPaid / _grandPaid * 100)
                            : 0.0;

                        return DataRow2(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    child: Text(
                                      (emp['employee_name'] as String)
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    emp['employee_name'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                '$orderCount',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _fmt(totalAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _fmt(totalPaid),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: totalPaid >= totalAmount
                                      ? AppTheme.successColor
                                      : AppTheme.warningColor,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _fmt(cash),
                                style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _fmt(transfer),
                                style: const TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _fmt(eWallet),
                                style: const TextStyle(
                                  color: Color(0xFF7B1FA2),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            DataCell(_buildPercentageBar(percentage)),
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
              color: AppTheme.primaryColor.withValues(alpha: 0.03),
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Text(
                  'TỔNG CỘNG',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                _buildFooterChip(
                  Icons.receipt_long,
                  '$_grandOrders đơn',
                  AppTheme.textSecondary,
                ),
                const SizedBox(width: 16),
                _buildFooterChip(
                  Icons.payments,
                  _fmt(_grandCash),
                  const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 16),
                _buildFooterChip(
                  Icons.account_balance,
                  _fmt(_grandTransfer),
                  const Color(0xFF1565C0),
                ),
                const SizedBox(width: 16),
                _buildFooterChip(
                  Icons.phone_android,
                  _fmt(_grandEWallet),
                  const Color(0xFF7B1FA2),
                ),
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _fmt(_grandPaid),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageBar(double percentage) {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[200],
              color: AppTheme.primaryColor,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
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
}
