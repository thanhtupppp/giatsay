import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../models/customer.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/numeric_keypad_widget.dart';
import 'pos_create_order_widget.dart';

/// POS Screen với 3 bước kiểm soát bằng mã vạch:
/// 1. Tạo đơn + In 2 bill
/// 2. Giặt xong (scan để cập nhật status)
/// 3. Trả đồ + Thanh toán
class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _barcodeController = TextEditingController();
  final _barcodeFocusNode = FocusNode();

  final _orderRepo = OrderRepository();
  final _customerRepo = CustomerRepository();

  // Scanned order data
  Order? _scannedOrder;
  Customer? _scannedCustomer;
  List<Map<String, dynamic>> _scannedOrderItems = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Payment
  String _selectedPaymentMethod = AppConstants.paymentCash;

  // Show numeric keypad for manual entry
  bool _showKeypad = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Auto focus barcode field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  void _onTabChanged() {
    // Clear data when switching tabs
    setState(() {
      _scannedOrder = null;
      _scannedCustomer = null;
      _scannedOrderItems = [];
      _errorMessage = null;
      _successMessage = null;
      _barcodeController.clear();
    });
    _barcodeFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _barcodeController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
      _scannedOrder = null;
      _scannedCustomer = null;
      _scannedOrderItems = [];
    });

    try {
      // Search by barcode or order code
      Order? order = await _orderRepo.getByBarcode(barcode);
      order ??= await _orderRepo.getByCode(barcode);

      if (order == null) {
        setState(() {
          _errorMessage = 'Không tìm thấy đơn hàng với mã: $barcode';
          _isLoading = false;
        });
        return;
      }

      // Get customer info
      final customer = await _customerRepo.getById(order.customerId);
      if (customer == null) {
        setState(() {
          _errorMessage = 'Không tìm thấy thông tin khách hàng';
          _isLoading = false;
        });
        return;
      }

      // Get order items
      final orderItems = await _orderRepo.getOrderItemsWithServiceName(
        order.id!,
      );

      setState(() {
        _scannedOrder = order;
        _scannedCustomer = customer;
        _scannedOrderItems = orderItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi: $e';
        _isLoading = false;
      });
    }
  }

  /// Bước 2: Cập nhật trạng thái đã giặt xong
  Future<void> _markAsWashed() async {
    if (_scannedOrder == null) return;

    // Validate current status
    if (_scannedOrder!.status == AppConstants.orderStatusDelivered) {
      setState(() {
        _errorMessage = 'Đơn hàng này đã được giao rồi!';
      });
      return;
    }

    if (_scannedOrder!.status == AppConstants.orderStatusWashed) {
      setState(() {
        _errorMessage = 'Đơn hàng này đã được đánh dấu giặt xong rồi!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _orderRepo.updateStatus(
        _scannedOrder!.id!,
        AppConstants.orderStatusWashed,
      );

      setState(() {
        _successMessage =
            'Đã cập nhật: Đơn hàng ${_scannedOrder!.orderCode} đã giặt xong!';
        _scannedOrder = _scannedOrder!.copyWith(
          status: AppConstants.orderStatusWashed,
        );
        _isLoading = false;
      });

      // Clear after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _scannedOrder = null;
            _scannedCustomer = null;
            _scannedOrderItems = [];
            _successMessage = null;
            _barcodeController.clear();
          });
          _barcodeFocusNode.requestFocus();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi cập nhật: $e';
        _isLoading = false;
      });
    }
  }

  /// Bước 3: Trả đồ + Thanh toán
  Future<void> _completeDelivery() async {
    if (_scannedOrder == null) return;

    // Validate current status
    if (_scannedOrder!.status == AppConstants.orderStatusDelivered) {
      setState(() {
        _errorMessage = 'Đơn hàng này đã được giao rồi!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Update payment
      await _orderRepo.updatePayment(
        _scannedOrder!.id!,
        _scannedOrder!.totalAmount,
        _selectedPaymentMethod,
      );

      // Update status to delivered
      await _orderRepo.updateStatus(
        _scannedOrder!.id!,
        AppConstants.orderStatusDelivered,
      );

      setState(() {
        _successMessage = 'Đã hoàn thành đơn hàng ${_scannedOrder!.orderCode}!';
        _isLoading = false;
      });

      // Clear after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _scannedOrder = null;
            _scannedCustomer = null;
            _scannedOrderItems = [];
            _successMessage = null;
            _barcodeController.clear();
          });
          _barcodeFocusNode.requestFocus();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi hoàn thành đơn: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'Quay lại',
        ),
        title: Row(
          children: [
            Icon(Icons.point_of_sale, color: Colors.white),
            const SizedBox(width: 12),
            const Text('POS - Quét mã vạch'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // Quick link to orders
          TextButton.icon(
            onPressed: () => context.go('/orders'),
            icon: const Icon(Icons.list_alt, color: Colors.white70),
            label: const Text(
              'Danh sách đơn',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Tab bar - modernized
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1565C0),
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: const Color(0xFF1565C0),
              indicatorWeight: 4,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  height: 70,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _tabController.index == 0
                              ? const Color(0xFF1565C0).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_shopping_cart, size: 28),
                      ),
                      const SizedBox(height: 4),
                      const Text('Tạo đơn'),
                    ],
                  ),
                ),
                Tab(
                  height: 70,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _tabController.index == 1
                              ? Colors.orange.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_laundry_service,
                          size: 28,
                          color: _tabController.index == 1
                              ? Colors.orange[700]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Giặt xong'),
                    ],
                  ),
                ),
                Tab(
                  height: 70,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _tabController.index == 2
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.check_circle,
                          size: 28,
                          color: _tabController.index == 2
                              ? const Color(0xFF4CAF50)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('Trả đồ'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Messages
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.errorColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: AppTheme.errorColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.errorColor),
                    onPressed: () => setState(() => _errorMessage = null),
                  ),
                ],
              ),
            ),

          if (_successMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: TextStyle(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.successColor),
                    onPressed: () => setState(() => _successMessage = null),
                  ),
                ],
              ),
            ),

          // Content area
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreateOrderTab(),
                _buildWashCompleteTab(),
                _buildDeliveryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 1: Tạo đơn mới - form inline
  Widget _buildCreateOrderTab() {
    return POSCreateOrderWidget(
      onOrderCreated: () {
        // Có thể switch sang tab khác hoặc refresh
      },
    );
  }

  /// Tab 2: Giặt xong
  Widget _buildWashCompleteTab() {
    if (_scannedOrder == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[400]!, Colors.orange[600]!],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_laundry_service,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Đánh dấu giặt xong',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Quét mã vạch hoặc nhập mã số',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Scanner input field
            Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: TextField(
                controller: _barcodeController,
                focusNode: _barcodeFocusNode,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 28,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Quét mã vạch...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 20),
                  prefixIcon: const Icon(Icons.qr_code_scanner, size: 32),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_barcodeController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 28),
                          onPressed: () {
                            _barcodeController.clear();
                            setState(() {});
                          },
                        ),
                      IconButton(
                        icon: Icon(
                          _showKeypad ? Icons.keyboard_hide : Icons.dialpad,
                          size: 28,
                          color: _showKeypad ? Colors.orange : Colors.grey[600],
                        ),
                        tooltip: _showKeypad ? 'Ẩn bàn phím' : 'Nhập tay',
                        onPressed: () =>
                            setState(() => _showKeypad = !_showKeypad),
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.orange[600]!,
                      width: 3,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                ),
                keyboardType: TextInputType.none, // Hide system keyboard
                onSubmitted: (_) => _scanBarcode(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(height: 16),

            // Search button
            SizedBox(
              width: 200,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _barcodeController.text.isEmpty
                    ? null
                    : _scanBarcode,
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search, size: 24),
                label: const Text(
                  'TÌM KIẾ́M',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            // Numeric keypad (collapsible)
            if (_showKeypad) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 350,
                child: NumericKeypadWidget(
                  value: _barcodeController.text,
                  onValueChanged: (value) {
                    setState(() => _barcodeController.text = value);
                  },
                  onEnter: _scanBarcode,
                  hintText: 'Nhập mã số...',
                ),
              ),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _buildOrderCard(
        actionButton: ElevatedButton.icon(
          onPressed: _isLoading ? null : _markAsWashed,
          icon: const Icon(Icons.check),
          label: const Text('XÁC NHẬN GIẶT XONG'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ),
    );
  }

  /// Tab 3: Trả đồ + Thanh toán
  Widget _buildDeliveryTab() {
    if (_scannedOrder == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF4CAF50), const Color(0xFF388E3C)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trả đồ & Thanh toán',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Quét mã vạch hoặc nhập mã số',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Scanner input field
            Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: TextField(
                controller: _barcodeController,
                focusNode: _barcodeFocusNode,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 28,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Quét mã vạch...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 20),
                  prefixIcon: const Icon(Icons.qr_code_scanner, size: 32),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_barcodeController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 28),
                          onPressed: () {
                            _barcodeController.clear();
                            setState(() {});
                          },
                        ),
                      IconButton(
                        icon: Icon(
                          _showKeypad ? Icons.keyboard_hide : Icons.dialpad,
                          size: 28,
                          color: _showKeypad
                              ? const Color(0xFF4CAF50)
                              : Colors.grey[600],
                        ),
                        tooltip: _showKeypad ? 'Ẩn bàn phím' : 'Nhập tay',
                        onPressed: () =>
                            setState(() => _showKeypad = !_showKeypad),
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 3,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                ),
                keyboardType: TextInputType.none, // Hide system keyboard
                onSubmitted: (_) => _scanBarcode(),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(height: 16),

            // Search button
            SizedBox(
              width: 200,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _barcodeController.text.isEmpty
                    ? null
                    : _scanBarcode,
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search, size: 24),
                label: const Text(
                  'TÌM KIẾ́M',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            // Numeric keypad (collapsible)
            if (_showKeypad) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 350,
                child: NumericKeypadWidget(
                  value: _barcodeController.text,
                  onValueChanged: (value) {
                    setState(() => _barcodeController.text = value);
                  },
                  onEnter: _scanBarcode,
                  hintText: 'Nhập mã số...',
                ),
              ),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildOrderCard(
            showPayment: true,
            actionButton: ElevatedButton.icon(
              onPressed: _isLoading ? null : _completeDelivery,
              icon: const Icon(Icons.check_circle),
              label: const Text('HOÀN THÀNH TRẢ ĐỒ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard({Widget? actionButton, bool showPayment = false}) {
    if (_scannedOrder == null || _scannedCustomer == null) {
      return const SizedBox.shrink();
    }

    final order = _scannedOrder!;
    final customer = _scannedCustomer!;
    final statusColor = AppTheme.getStatusColor(order.status);
    final currencyFormat = NumberFormat.currency(locale: 'vi', symbol: 'đ');

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mã đơn: ${order.orderCode}',
                        style: AppTheme.heading3,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          AppConstants.orderStatusLabels[order.status] ??
                              order.status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 32),

            // Customer info
            Row(
              children: [
                const Icon(Icons.person, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Khách hàng: ',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  customer.name,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'SĐT: ',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(customer.phone, style: AppTheme.bodyLarge),
              ],
            ),

            const Divider(height: 32),

            // Order items
            Text(
              'Chi tiết dịch vụ:',
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._scannedOrderItems.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item['service_name']} x${item['quantity']}',
                        style: AppTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      currencyFormat.format(item['subtotal']),
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 24),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TỔNG CỘNG:', style: AppTheme.heading3),
                Text(
                  currencyFormat.format(order.totalAmount),
                  style: AppTheme.heading2.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),

            if (order.paidAmount > 0 &&
                order.paidAmount < order.totalAmount) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Đã thanh toán:', style: AppTheme.bodyMedium),
                  Text(
                    currencyFormat.format(order.paidAmount),
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Còn lại:',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    currencyFormat.format(order.remainingAmount),
                    style: AppTheme.heading3.copyWith(
                      color: AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ],

            // Payment selection (only for delivery tab)
            if (showPayment &&
                order.status != AppConstants.orderStatusDelivered) ...[
              const Divider(height: 32),
              Text(
                'Phương thức thanh toán:',
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppConstants.paymentMethods.map((method) {
                  final isSelected = _selectedPaymentMethod == method;
                  return ChoiceChip(
                    label: Text(
                      AppConstants.paymentMethodLabels[method] ?? method,
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedPaymentMethod = method;
                        });
                      }
                    },
                    selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
            ],

            // Action button
            if (actionButton != null &&
                order.status != AppConstants.orderStatusDelivered) ...[
              const SizedBox(height: 24),
              Center(child: actionButton),
            ],

            // Already delivered message
            if (order.status == AppConstants.orderStatusDelivered)
              Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.successColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Đơn hàng đã hoàn thành',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                          ),
                          if (order.completedDate != null)
                            Text(
                              'Giao ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(order.completedDate!)}',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
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
