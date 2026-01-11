import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../models/customer.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../core/services/print_service.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/main_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import '../../core/services/auth_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  
  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _orderRepo = OrderRepository();
  final _customerRepo = CustomerRepository();
  
  Order? _order;
  Customer? _customer;
  List<Map<String, dynamic>> _orderItems = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }
  
  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final order = await _orderRepo.getById(widget.orderId);
      if (order == null) throw Exception('Không tìm thấy đơn hàng');
      
      final customer = await _customerRepo.getById(order.customerId);
      if (customer == null) throw Exception('Không tìm thấy thông tin khách hàng');
      
      final items = await _orderRepo.getOrderItemsWithServiceName(widget.orderId);
      
      if (mounted) {
        setState(() {
          _order = order;
          _customer = customer;
          _orderItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
  
  Future<void> _processPayment() async {
    if (_order == null) return;
    
    final remainingAmount = _order!.totalAmount - _order!.paidAmount;
    if (remainingAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đơn hàng đã thanh toán đầy đủ')),
      );
      return;
    }
    
    final amountController = TextEditingController(
      text: remainingAmount.toString(),
    );
    String paymentMethod = AppConstants.paymentCash;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.payments,
                        color: AppTheme.successColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thanh toán',
                            style: AppTheme.heading3.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mã đơn: ${_order!.orderCode}',
                            style: AppTheme.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tổng tiền:', style: AppTheme.bodyMedium),
                          Text(
                            NumberFormat.currency(locale: 'vi', symbol: 'đ')
                                .format(_order!.totalAmount),
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Đã trả:', style: AppTheme.bodyMedium),
                          Text(
                            NumberFormat.currency(locale: 'vi', symbol: 'đ')
                                .format(_order!.paidAmount),
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Còn lại:',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            NumberFormat.currency(locale: 'vi', symbol: 'đ')
                                .format(remainingAmount),
                            style: AppTheme.heading3.copyWith(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: InputDecoration(
                    labelText: 'Phương thức thanh toán',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: AppConstants.paymentMethods.map((method) {
                    return DropdownMenuItem(
                      value: method,
                      child: Text(AppConstants.paymentMethodLabels[method]!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      paymentMethod = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Số tiền thanh toán',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    suffixText: 'đ',
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                
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
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(Icons.check),
                        label: const Text(
                          'Xác nhận',
                          style: TextStyle(fontSize: 16),
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
    );
    
    if (result == true) {
      if (!mounted) return;
      
      final amount = double.tryParse(amountController.text) ?? 0;
      if (amount <= 0) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Số tiền không hợp lệ')),
            );
        }
        return;
      }
      
      try {
        final newPaidAmount = _order!.paidAmount + amount;
        var updatedOrder = _order!.copyWith(
          paidAmount: newPaidAmount,
          paymentMethod: paymentMethod,
        );

        // Auto-update status to Delivered if fully paid
        if (newPaidAmount >= _order!.totalAmount) {
          updatedOrder = updatedOrder.copyWith(
            status: AppConstants.orderStatusDelivered,
            deliveryDate: DateTime.now(),
          );
        }
        
        await _orderRepo.update(updatedOrder);
        await _loadOrderDetails();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'Đã thanh toán ${NumberFormat.currency(locale: 'vi', symbol: 'đ').format(amount)}',
                  ),
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
              content: Text('Lỗi thanh toán: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
    
    amountController.dispose();
  }
  
  Future<void> _printReceipt() async {
    if (_order == null || _customer == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final storeName = prefs.getString('store_name');
      final storeAddress = prefs.getString('store_address');
      final storePhone = prefs.getString('store_phone');
      final footerMessage = prefs.getString('print_footer_message');
      final paperSize = prefs.getString('print_paper_size') ?? 'roll80';
      
      PdfPageFormat format;
      switch (paperSize) {
        case 'a4':
          format = PdfPageFormat.a4;
          break;
        case 'a5':
          format = PdfPageFormat.a5;
          break;
        default:
          format = PdfPageFormat.roll80;
      }
      
      final employeeName = AuthService.instance.currentUser?.fullName ?? 'Admin';

      await PrintService.instance.printOrderReceipt(
        _order!,
        _customer!,
        _orderItems,
        storeName,
        employeeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        footerMessage: footerMessage,
        pageFormat: format,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tạo hóa đơn...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi in: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _printBarcode() async {
    if (_order == null || _customer == null) return;
    
    try {
      await PrintService.instance.printBarcodeLabel(
        _order!,
        _customer!,
        AppConstants.appName,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi in mã vạch')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi in: $e'),
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
        title: 'Chi tiết đơn hàng',
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_order == null || _customer == null) {
      return MainLayout(
        title: 'Chi tiết đơn hàng',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppTheme.textSecondary),
              const SizedBox(height: 16),
              const Text('Không tìm thấy đơn hàng'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/orders'),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      );
    }
    
    final remainingAmount = _order!.totalAmount - _order!.paidAmount;
    final statusColor = AppTheme.getStatusColor(_order!.status);
    
    return MainLayout(
      title: 'Chi tiết đơn hàng',
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
                  onPressed: () => context.go('/orders'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Đơn hàng #${_order!.orderCode}',
                              style: AppTheme.titleMedium.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                AppConstants.orderStatusLabels[_order!.status]!,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tạo ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(_order!.createdAt)}', 
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Action buttons
                if (remainingAmount > 0)
                  ElevatedButton.icon(
                    onPressed: _processPayment,
                    icon: const Icon(Icons.payments),
                    label: const Text('Thanh toán'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _printReceipt,
                  icon: const Icon(Icons.print),
                  label: const Text('In hóa đơn'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _printBarcode,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('In mã vạch'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column - Customer & Order info
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      // Customer info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('Thông tin khách hàng', Icons.person),
                              _buildInfoRow('Tên khách hàng', _customer!.name),
                              _buildInfoRow('Số điện thoại', _customer!.phone),
                              if (_customer!.address != null)
                                _buildInfoRow('Địa chỉ', _customer!.address!),
                              if (_customer!.email != null)
                                _buildInfoRow('Email', _customer!.email!),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Order info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('Thông tin đơn hàng', Icons.receipt_long),
                              _buildInfoRow(
                                'Ngày nhận',
                                DateFormat('dd/MM/yyyy HH:mm').format(_order!.receivedDate),
                              ),
                              _buildInfoRow(
                                'Ngày giao dự kiến',
                                _order!.deliveryDate != null
                                    ? DateFormat('dd/MM/yyyy HH:mm').format(_order!.deliveryDate!)
                                    : '-',
                              ),
                              if (_order!.notes != null)
                                _buildInfoRow('Ghi chú', _order!.notes!),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Right column - Services & Payment
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Services
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('Dịch vụ', Icons.local_laundry_service),
                              
                               ..._orderItems.map((item) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['service_name'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                            Text(
                                              '${NumberFormat.currency(locale: 'vi', symbol: 'đ').format(item['unit_price'])} x ${item['quantity']}',
                                              style: TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        NumberFormat.currency(locale: 'vi', symbol: 'đ')
                                            .format(item['subtotal']),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Payment summary
                      Card(
                        color: AppTheme.primaryColor.withValues(alpha: 0.05),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryColumn(
                                      'Tổng tiền', 
                                      _order!.totalAmount, 
                                      color: Colors.black
                                    ),
                                  ),
                                  Container(width: 1, height: 40, color: AppTheme.dividerColor),
                                  Expanded(
                                    child: _buildSummaryColumn(
                                      'Đã trả', 
                                      _order!.paidAmount, 
                                      color: AppTheme.successColor
                                    ),
                                  ),
                                  Container(width: 1, height: 40, color: AppTheme.dividerColor),
                                  Expanded(
                                    child: _buildSummaryColumn(
                                      'Còn lại', 
                                      remainingAmount, 
                                      color: remainingAmount > 0 ? AppTheme.errorColor : AppTheme.successColor,
                                      isBold: true,
                                      showIcon: remainingAmount > 0
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600], // Darker gray
                fontSize: 13, // Smaller font
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSectionTitle(String title, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Text(title, style: AppTheme.heading3),
          ],
        ),
        const Divider(height: 24),
      ],
    );

  }

  Widget _buildSummaryColumn(String label, double amount, {
    required Color color, 
    bool isBold = false,
    bool showIcon = false,
  }) {
    return Column(
      children: [
        Text(label, style: AppTheme.bodySmall),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showIcon) ...[
              const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor, size: 16),
              const SizedBox(width: 4),
            ],
            Text(
              NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0).format(amount),
              style: TextStyle(
                color: color,
                fontSize: isBold ? 18 : 16,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
