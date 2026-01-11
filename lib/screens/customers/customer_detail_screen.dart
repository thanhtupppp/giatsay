import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../models/customer.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/order_repository.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/main_layout.dart';

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;
  
  const CustomerDetailScreen({
    super.key,
    required this.customerId,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _customerRepo = CustomerRepository();
  final _orderRepo = OrderRepository();
  
  Customer? _customer;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  
  double _totalSpent = 0;
  int _totalOrders = 0;
  int _pendingOrders = 0;
  
  @override
  void initState() {
    super.initState();
    _loadCustomerDetails();
  }
  
  Future<void> _loadCustomerDetails() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final customer = await _customerRepo.getById(widget.customerId);
      if (customer == null) throw Exception('Không tìm thấy khách hàng');
      
      final orders = await _orderRepo.getOrdersByCustomer(widget.customerId);
      
      // Calculate statistics
      double totalSpent = 0;
      int pendingOrders = 0;
      
      for (final order in orders) {
        totalSpent += (order['total_amount'] as num).toDouble();
        final status = order['status'] as String;
        if (status != AppConstants.orderStatusDelivered) {
          pendingOrders++;
        }
      }
      
      setState(() {
        _customer = customer;
        _orders = orders;
        _totalSpent = totalSpent;
        _totalOrders = orders.length;
        _pendingOrders = pendingOrders;
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
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MainLayout(
        title: 'Chi tiết khách hàng',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_customer == null) {
      return MainLayout(
        title: 'Chi tiết khách hàng',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.textSecondary),
              const SizedBox(height: 16),
              const Text('Không tìm thấy khách hàng'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/customers'),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      );
    }
    
    return MainLayout(
      title: 'Chi tiết khách hàng',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/customers'),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    _customer!.name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customer!.name,
                        style: AppTheme.heading2,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _customer!.phone,
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Statistics cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Tổng đơn hàng',
                    _totalOrders.toString(),
                    Icons.receipt_long,
                    AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Đơn đang xử lý',
                    _pendingOrders.toString(),
                    Icons.pending,
                    AppTheme.warningColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Tổng chi tiêu',
                    NumberFormat.currency(locale: 'vi', symbol: 'đ').format(_totalSpent),
                    Icons.account_balance_wallet,
                    AppTheme.successColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left - Customer info
                Expanded(
                  flex: 1,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thông tin khách hàng',
                            style: AppTheme.heading3,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow('Tên', _customer!.name),
                          _buildInfoRow('Số điện thoại', _customer!.phone),
                          if (_customer!.email != null)
                            _buildInfoRow('Email', _customer!.email!),
                          if (_customer!.address != null)
                            _buildInfoRow('Địa chỉ', _customer!.address!),
                          _buildInfoRow(
                            'Ngày tạo',
                            DateFormat('dd/MM/yyyy').format(_customer!.createdAt),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Right - Order history
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lịch sử đơn hàng',
                                style: AppTheme.heading3,
                              ),
                              TextButton.icon(
                                onPressed: () => context.go('/orders/create'),
                                icon: const Icon(Icons.add),
                                label: const Text('Tạo đơn mới'),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          
                          if (_orders.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 64,
                                      color: AppTheme.textSecondary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Chưa có đơn hàng nào',
                                      style: AppTheme.bodyLarge.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 400,
                              child: DataTable2(
                                columnSpacing: 12,
                                horizontalMargin: 0,
                                minWidth: 600,
                                columns: const [
                                  DataColumn2(
                                    label: Text('Mã đơn'),
                                    size: ColumnSize.M,
                                  ),
                                  DataColumn2(
                                    label: Text('Ngày nhận'),
                                    size: ColumnSize.M,
                                  ),
                                  DataColumn2(
                                    label: Text('Tổng tiền'),
                                    size: ColumnSize.M,
                                  ),
                                  DataColumn2(
                                    label: Text('Trạng thái'),
                                    size: ColumnSize.M,
                                  ),
                                ],
                                rows: _orders.map((order) {
                                  final status = order['status'] as String;
                                  final statusColor = AppTheme.getStatusColor(status);
                                  
                                  return DataRow2(
                                    onTap: () => context.go('/orders/${order['id']}'),
                                    cells: [
                                      DataCell(
                                        Text(
                                          order['order_code'] as String,
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          DateFormat('dd/MM/yyyy').format(
                                            DateTime.parse(order['received_date'] as String),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          NumberFormat.currency(locale: 'vi', symbol: 'đ')
                                              .format(order['total_amount']),
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
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: statusColor),
                                          ),
                                          child: Text(
                                            AppConstants.orderStatusLabels[status]!,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTheme.heading3.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
