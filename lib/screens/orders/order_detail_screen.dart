import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/order.dart';
import '../../models/customer.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../core/services/print_service.dart';
import '../../core/services/auth_service.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/inputs.dart';
import '../../widgets/ui/dialogs.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

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
      if (customer == null) {
        throw Exception('Không tìm thấy thông tin khách hàng');
      }

      final items = await _orderRepo.getOrderItemsWithServiceName(
        widget.orderId,
      );

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
        showAppAlertDialog(
          context,
          title: 'Lỗi',
          content: 'Lỗi tải dữ liệu: $e',
          buttonText: 'Đóng',
        );
      }
    }
  }

  Future<void> _processPayment() async {
    if (_order == null) return;

    final remainingAmount = _order!.totalAmount - _order!.paidAmount;
    if (remainingAmount <= 0) {
      showAppAlertDialog(
        context,
        title: 'Thông báo',
        content: 'Đơn hàng đã thanh toán đầy đủ',
      );
      return;
    }

    final amountController = TextEditingController(
      text: remainingAmount.toString(),
    );
    final cashReceivedController = TextEditingController();
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
                              NumberFormat.currency(
                                locale: 'vi',
                                symbol: 'đ',
                              ).format(_order!.totalAmount),
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
                              NumberFormat.currency(
                                locale: 'vi',
                                symbol: 'đ',
                              ).format(_order!.paidAmount),
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
                              NumberFormat.currency(
                                locale: 'vi',
                                symbol: 'đ',
                              ).format(remainingAmount),
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

                  AppDropdown<String>(
                    label: 'Phương thức thanh toán',
                    value: paymentMethod,
                    items: AppConstants.paymentMethods.map((method) {
                      return DropdownMenuItem(
                        value: method,
                        child: Text(AppConstants.paymentMethodLabels[method]!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        paymentMethod = value!;
                        cashReceivedController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  AppNumberField(
                    controller: amountController,
                    label: 'Số tiền thanh toán',
                    suffixText: 'đ',
                  ),

                  // Cash change calculation
                  if (paymentMethod == AppConstants.paymentCash) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tính tiền thối:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: cashReceivedController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Khách đưa',
                              suffixText: 'đ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final received =
                                  double.tryParse(
                                    cashReceivedController.text.replaceAll(
                                      RegExp(r'[^0-9]'),
                                      '',
                                    ),
                                  ) ??
                                  0;
                              final payAmount =
                                  double.tryParse(amountController.text) ??
                                  remainingAmount;
                              final change = received - payAmount;

                              if (received <= 0) return const SizedBox.shrink();

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: change >= 0
                                      ? Colors.green[50]
                                      : Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: change >= 0
                                        ? Colors.green[300]!
                                        : Colors.red[300]!,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      change >= 0
                                          ? 'Tiền thối lại:'
                                          : 'Còn thiếu:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: change >= 0
                                            ? Colors.green[800]
                                            : Colors.red[800],
                                      ),
                                    ),
                                    Text(
                                      NumberFormat.currency(
                                        locale: 'vi',
                                        symbol: 'đ',
                                      ).format(change.abs()),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: change >= 0
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          label: 'Hủy',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          label: 'Xác nhận',
                          icon: Icons.check,
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
    );

    if (result == true) {
      if (!mounted) return;

      final amount = double.tryParse(amountController.text) ?? 0;
      if (amount <= 0) {
        if (mounted) {
          showAppAlertDialog(
            context,
            title: 'Lỗi',
            content: 'Số tiền không hợp lệ',
          );
        }
        return;
      }

      try {
        final newPaidAmount = _order!.paidAmount + amount;
        final currentUser = AuthService.instance.currentUser;

        // Update payment and auto-create income Transaction
        await _orderRepo.updatePayment(
          _order!.id!,
          newPaidAmount,
          paymentMethod,
          incrementAmount: amount,
          employeeId: currentUser?.id,
        );

        // Auto-update status to Delivered if fully paid
        if (newPaidAmount >= _order!.totalAmount) {
          await _orderRepo.updateStatus(
            _order!.id!,
            AppConstants.orderStatusDelivered,
          );
        }

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
          showAppAlertDialog(
            context,
            title: 'Lỗi',
            content: 'Lỗi thanh toán: $e',
          );
        }
      }
    }

    amountController.dispose();
    cashReceivedController.dispose();
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

      final employeeName =
          AuthService.instance.currentUser?.fullName ?? 'Admin';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đang tạo hóa đơn...')));
      }
    } catch (e) {
      if (mounted) {
        showAppAlertDialog(context, title: 'Lỗi in', content: e.toString());
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã gửi in mã vạch')));
      }
    } catch (e) {
      if (mounted) {
        showAppAlertDialog(context, title: 'Lỗi in', content: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      title: 'Chi tiết đơn hàng',
      isLoading: _isLoading,
      actions: _buildHeaderActions(),
      child: _order == null ? _buildNotFound() : _buildContent(),
    );
  }

  List<Widget> _buildHeaderActions() {
    if (_order == null) return [];

    final remainingAmount = _order!.totalAmount - _order!.paidAmount;

    return [
      if (remainingAmount > 0)
        PrimaryButton(
          onPressed: _processPayment,
          label: 'Thanh toán',
          icon: Icons.payments,
        ),
      const SizedBox(width: 8),
      SecondaryButton(
        onPressed: _printReceipt,
        label: 'In hóa đơn',
        icon: Icons.print,
      ),
      const SizedBox(width: 8),
      SecondaryButton(
        onPressed: _printBarcode,
        label: 'In tem', // Shortened label
        icon: Icons.qr_code,
      ),
    ];
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text('Không tìm thấy đơn hàng'),
          const SizedBox(height: 16),
          PrimaryButton(
            onPressed: () => context.go('/orders'),
            label: 'Quay lại',
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final remainingAmount = _order!.totalAmount - _order!.paidAmount;
    final statusColor = AppTheme.getStatusColor(_order!.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Title & Status (If we moved actions to header, we might still want to see Order #)
          // But Header already has title "Chi tiết đơn hàng". Maybe we change Header Title to "Đơn hàng #..."?
          // For now, let's keep a sub-header or breadcrumb if needed, or just emphasize order # in Info.
          // Let's create a prominent status banner/header card.
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/orders'),
              ),
              Text('Đơn hàng #${_order!.orderCode}', style: AppTheme.heading2),
              const SizedBox(width: 16),
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
              const Spacer(),
              // We could put date here
              Text(
                'Tạo: ${DateFormat('dd/MM/yyyy HH:mm').format(_order!.createdAt)}',
                style: AppTheme.bodySmall,
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
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            title: 'Thông tin khách hàng',
                            icon: Icons.person,
                          ),
                          _buildInfoRow('Tên khách hàng', _customer!.name),
                          _buildInfoRow('Số điện thoại', _customer!.phone),
                          if (_customer!.address != null)
                            _buildInfoRow('Địa chỉ', _customer!.address!),
                          if (_customer!.email != null)
                            _buildInfoRow('Email', _customer!.email!),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Order info
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            title: 'Thông tin đơn hàng',
                            icon: Icons.receipt_long,
                          ),
                          _buildInfoRow(
                            'Ngày nhận',
                            DateFormat(
                              'dd/MM/yyyy HH:mm',
                            ).format(_order!.receivedDate),
                          ),
                          _buildInfoRow(
                            'Ngày giao (DK)',
                            _order!.deliveryDate != null
                                ? DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                  ).format(_order!.deliveryDate!)
                                : '-',
                          ),
                          if (_order!.notes != null)
                            _buildInfoRow('Ghi chú', _order!.notes!),
                        ],
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
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            title: 'Dịch vụ',
                            icon: Icons.local_laundry_service,
                          ),

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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    NumberFormat.currency(
                                      locale: 'vi',
                                      symbol: 'đ',
                                    ).format(item['subtotal']),
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
                    const SizedBox(height: 16),

                    // Payment summary
                    AppCard(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryColumn(
                                  'Tổng tiền',
                                  _order!.totalAmount,
                                  color: Colors.black,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppTheme.dividerColor,
                              ),
                              Expanded(
                                child: _buildSummaryColumn(
                                  'Đã trả',
                                  _order!.paidAmount,
                                  color: AppTheme.successColor,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppTheme.dividerColor,
                              ),
                              Expanded(
                                child: _buildSummaryColumn(
                                  'Còn lại',
                                  remainingAmount,
                                  color: remainingAmount > 0
                                      ? AppTheme.errorColor
                                      : AppTheme.successColor,
                                  isBold: true,
                                  showIcon: remainingAmount > 0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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
                color: Colors.grey[600],
                fontSize: 13,
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

  Widget _buildSummaryColumn(
    String label,
    double amount, {
    required Color color,
    bool isBold = false,
    bool showIcon = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              NumberFormat.currency(locale: 'vi', symbol: 'đ').format(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
            if (showIcon) ...[
              const SizedBox(width: 4),
              Icon(Icons.warning_amber_rounded, color: color, size: 16),
            ],
          ],
        ),
      ],
    );
  }
}
