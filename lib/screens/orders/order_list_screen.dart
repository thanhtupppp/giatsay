import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../models/order.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../core/services/print_service.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/inputs.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final _orderRepo = OrderRepository();
  final _customerRepo = CustomerRepository();

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _selectedStatus;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orders = await _orderRepo.getAllWithCustomerInfo(
        status: _selectedStatus,
      );

      setState(() {
        _orders = orders;
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

  List<Map<String, dynamic>> get _filteredOrders {
    if (_searchQuery.isEmpty) return _orders;

    final query = _searchQuery.toLowerCase();
    return _orders.where((order) {
      final orderCode = (order['order_code'] as String?)?.toLowerCase() ?? '';
      final customerName =
          (order['customer_name'] as String?)?.toLowerCase() ?? '';
      final customerPhone =
          (order['customer_phone'] as String?)?.toLowerCase() ?? '';

      return orderCode.contains(query) ||
          customerName.contains(query) ||
          customerPhone.contains(query);
    }).toList();
  }

  Future<void> _printBarcode(int orderId) async {
    try {
      // Get order details
      final orderData = _orders.firstWhere((o) => o['id'] == orderId);
      final order = Order.fromMap(orderData);

      // Get customer
      final customer = await _customerRepo.getById(order.customerId);
      if (customer == null) {
        throw Exception('Không tìm thấy thông tin khách hàng');
      }

      // Print
      await PrintService.instance.printBarcodeLabel(
        order,
        customer,
        'LAUNDRY MANAGEMENT',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã gửi in mã vạch'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi in mã vạch: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      title: 'Quản lý đơn hàng',
      actions: [
        PrimaryButton(
          onPressed: () => context.go('/orders/create'),
          icon: Icons.add,
          label: 'Tạo đơn hàng',
        ),
      ],
      child: Column(
        children: [
          // Filter & Search Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Filter
                Expanded(
                  flex: 2,
                  child: AppDropdown<String>(
                    label: 'Trạng thái',
                    value: _selectedStatus,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tất cả'),
                      ),
                      ...AppConstants.orderStatuses.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(
                            AppConstants.orderStatusLabels[status] ?? status,
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                      _loadOrders();
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Search
                Expanded(
                  flex: 5,
                  child: AppTextField(
                    label: 'Tìm kiếm',
                    hintText: 'Nhập mã đơn, tên khách hàng, số điện thoại...',
                    prefixIcon: Icons.search,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Data Table Card
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero, // Table handles padding
              child: Column(
                children: [
                  const SectionHeader(title: 'Danh sách đơn hàng'),
                  const Divider(height: 1),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredOrders.isEmpty
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
                                  'Không có đơn hàng nào',
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors
                                  .transparent, // Hide default table dividers if desired
                            ),
                            child: DataTable2(
                              columnSpacing: 24,
                              horizontalMargin: 24,
                              minWidth: 1000,
                              dataRowHeight: 60,
                              headingRowHeight: 50,
                              headingRowColor: WidgetStateProperty.all(
                                Colors.grey[50],
                              ),
                              columns: [
                                const DataColumn2(
                                  label: Text(
                                    'MÃ ĐƠN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  size: ColumnSize.S,
                                ),
                                const DataColumn2(
                                  label: Text(
                                    'KHÁCH HÀNG',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  size: ColumnSize.L,
                                ),
                                const DataColumn2(
                                  label: Text(
                                    'SĐT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  size: ColumnSize.M,
                                ),
                                const DataColumn2(
                                  label: Text(
                                    'NGÀY NHẬN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  size: ColumnSize.M,
                                ),
                                const DataColumn2(
                                  label: Text(
                                    'NGÀY GIAO',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  size: ColumnSize.M,
                                ),
                                const DataColumn2(
                                  label: Text(
                                    'TỔNG TIỀN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  size: ColumnSize.M,
                                  numeric: true,
                                ),
                                const DataColumn2(
                                  label: Text(
                                    'TRẠNG THÁI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  size: ColumnSize.M,
                                ),
                                const DataColumn2(
                                  label: Text(
                                    'THAO TÁC',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  size: ColumnSize.L,
                                ),
                              ],
                              rows: _filteredOrders.map((order) {
                                final status = order['status'] as String;
                                final statusColor = AppTheme.getStatusColor(
                                  status,
                                );

                                return DataRow2(
                                  onTap: () =>
                                      context.go('/orders/${order['id']}'),
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
                                      Text(order['customer_name'] as String),
                                    ),
                                    DataCell(
                                      Text(order['customer_phone'] as String),
                                    ),
                                    DataCell(
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(
                                          DateTime.parse(
                                            order['received_date'] as String,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        order['delivery_date'] != null
                                            ? DateFormat('dd/MM/yyyy').format(
                                                DateTime.parse(
                                                  order['delivery_date']
                                                      as String,
                                                ),
                                              )
                                            : '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        NumberFormat.currency(
                                          locale: 'vi',
                                          symbol: 'đ',
                                        ).format(order['total_amount']),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
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
                                          color: statusColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: statusColor.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          AppConstants
                                                  .orderStatusLabels[status] ??
                                              status,
                                          style: TextStyle(
                                            color: statusColor,
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
                                          Tooltip(
                                            message: 'In mã vạch',
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.qr_code,
                                                color: Colors.grey,
                                              ),
                                              iconSize: 20,
                                              onPressed: () => _printBarcode(
                                                order['id'] as int,
                                              ),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => context.go(
                                              '/orders/${order['id']}',
                                            ),
                                            icon: const Icon(
                                              Icons.visibility_outlined,
                                              size: 18,
                                            ),
                                            label: const Text('Chi tiết'),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.primaryColor,
                                            ),
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

                  // Footer Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Tổng số đơn: ${_filteredOrders.length}',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Tổng doanh thu dự kiến: ',
                          style: AppTheme.bodyLarge,
                        ),
                        Text(
                          NumberFormat.currency(
                            locale: 'vi',
                            symbol: 'đ',
                          ).format(
                            _filteredOrders.fold<double>(
                              0,
                              (sum, order) =>
                                  sum +
                                  (order['total_amount'] as num).toDouble(),
                            ),
                          ),
                          style: AppTheme.heading3.copyWith(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
