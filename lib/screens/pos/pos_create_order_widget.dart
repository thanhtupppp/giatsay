import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../models/customer.dart';
import '../../models/service.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/service_repository.dart';
import '../../repositories/order_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/print_service.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/pos_service_card.dart';

/// Widget tạo đơn hàng nhanh trong POS
class POSCreateOrderWidget extends StatefulWidget {
  final VoidCallback? onOrderCreated;

  const POSCreateOrderWidget({super.key, this.onOrderCreated});

  @override
  State<POSCreateOrderWidget> createState() => _POSCreateOrderWidgetState();
}

class _POSCreateOrderWidgetState extends State<POSCreateOrderWidget> {
  final _customerRepo = CustomerRepository();
  final _serviceRepo = ServiceRepository();
  final _orderRepo = OrderRepository();

  // Data
  List<Customer> _customers = [];
  List<Service> _services = [];
  bool _isLoading = true;
  bool _isCreating = false;

  // Form data
  Customer? _selectedCustomer;
  final Map<int, int> _serviceQuantities = {}; // serviceId -> quantity
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();

  // Delivery date
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 1));

  // Quick add customer mode
  bool _isAddingNewCustomer = false;

  // Store Info
  String? _storeName;
  String? _storeAddress;
  String? _storePhone;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadStoreInfo();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _storeName = prefs.getString('store_name'); // Không dùng giá trị mặc định
      _storeAddress = prefs.getString('store_address');
      _storePhone = prefs.getString('store_phone');
    });
  }

  Future<void> _showQuickStoreSettingsDialog() async {
    final nameCtrl = TextEditingController(text: _storeName);
    final addrCtrl = TextEditingController(text: _storeAddress);
    final phoneCtrl = TextEditingController(text: _storePhone);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cấu hình thông tin cửa hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên cửa hàng',
                hintText: 'VD: Giặt Sủi 24h',
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addrCtrl,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('store_name', nameCtrl.text);
              await prefs.setString('store_address', addrCtrl.text);
              await prefs.setString('store_phone', phoneCtrl.text);

              await _loadStoreInfo(); // Reload UI

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Lưu cấu hình'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _customerRepo.getAll();
      final services = await _serviceRepo.getAll();
      setState(() {
        _customers = customers;
        _services = services.where((s) => s.isActive).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  double get _totalAmount {
    double total = 0;
    for (final entry in _serviceQuantities.entries) {
      final service = _services.firstWhere((s) => s.id == entry.key);
      total += service.price * entry.value;
    }
    return total;
  }

  Future<void> _pickDeliveryDateTime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_deliveryDate),
      );
      if (mounted) {
        setState(() {
          _deliveryDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time?.hour ?? 18,
            time?.minute ?? 0,
          );
        });
      }
    }
  }

  void _incrementService(Service service) {
    setState(() {
      _serviceQuantities[service.id!] =
          (_serviceQuantities[service.id!] ?? 0) + 1;
    });
  }

  void _decrementService(Service service) {
    setState(() {
      final current = _serviceQuantities[service.id!] ?? 0;
      if (current > 1) {
        _serviceQuantities[service.id!] = current - 1;
      } else {
        _serviceQuantities.remove(service.id!);
      }
    });
  }

  Future<void> _quickAddCustomer() async {
    final name = _customerNameController.text.trim();
    final phone = _customerPhoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên và số điện thoại'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final customerId = await _customerRepo.create(
        Customer(name: name, phone: phone),
      );

      await _loadData();

      setState(() {
        _selectedCustomer = _customers.firstWhere((c) => c.id == customerId);
        _isAddingNewCustomer = false;
        _customerNameController.clear();
        _customerPhoneController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm khách hàng "$name"'),
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

  Future<void> _createOrder() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn khách hàng'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_serviceQuantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất 1 dịch vụ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('Chưa đăng nhập');

      // Create order
      final order = Order(
        orderCode: '',
        barcode: '',
        customerId: _selectedCustomer!.id!,
        employeeId: currentUser.id!,
        status: AppConstants.orderStatusReceived,
        totalAmount: _totalAmount,
        paidAmount: 0,
        receivedDate: DateTime.now(),
        deliveryDate: _deliveryDate,
      );

      final items = _serviceQuantities.entries.map((entry) {
        final service = _services.firstWhere((s) => s.id == entry.key);
        return OrderItem(
          orderId: 0,
          serviceId: entry.key,
          quantity: entry.value.toDouble(),
          unitPrice: service.price,
          subtotal: service.price * entry.value,
        );
      }).toList();

      final createdOrder = await _orderRepo.createOrderWithCode(order, items);

      // Get order items for printing
      final orderItemsForPrint = await _orderRepo.getOrderItemsWithServiceName(
        createdOrder.id!,
      );

      // Print 2 bills
      await PrintService.instance.printDualBills(
        createdOrder,
        _selectedCustomer!,
        orderItemsForPrint,
        _storeName, // Pass configured store name or null
        currentUser.fullName,
        storeAddress: _storeAddress,
        storePhone: _storePhone,
      );

      // Clear form
      setState(() {
        _selectedCustomer = null;
        _serviceQuantities.clear();
        _isCreating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đã tạo đơn #${createdOrder.orderCode} và in 2 bill!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );

        widget.onOrderCreated?.call();
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tạo đơn: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final currencyFormat = NumberFormat.currency(locale: 'vi', symbol: 'đ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Services grid
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.cleaning_services, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text('Chọn dịch vụ', style: AppTheme.heading3),
                  ],
                ),
                const SizedBox(height: 16),

                // Services grid - auto fit to screen
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final itemCount = _services.length;
                      if (itemCount == 0) {
                        return const Center(child: Text('Chưa có dịch vụ nào'));
                      }

                      // Calculate optimal grid layout
                      final availableWidth = constraints.maxWidth;
                      final availableHeight = constraints.maxHeight;

                      // Minimum card size for touch
                      const minCardWidth = 140.0;
                      const spacing = 12.0;

                      // Calculate columns based on width
                      int crossAxisCount = (availableWidth / minCardWidth)
                          .floor();
                      crossAxisCount = crossAxisCount.clamp(2, 6);

                      // Calculate rows needed
                      final rows = (itemCount / crossAxisCount).ceil();

                      // Calculate card height to fit all rows
                      final totalSpacing = (rows - 1) * spacing;
                      final cardHeight =
                          (availableHeight - totalSpacing) / rows;

                      // Calculate card width
                      final totalHSpacing = (crossAxisCount - 1) * spacing;
                      final cardWidth =
                          (availableWidth - totalHSpacing) / crossAxisCount;

                      // Aspect ratio
                      final aspectRatio = cardWidth / cardHeight;

                      return GridView.builder(
                        physics:
                            const NeverScrollableScrollPhysics(), // Disable scroll
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: aspectRatio.clamp(0.6, 1.8),
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                        ),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          final quantity = _serviceQuantities[service.id!] ?? 0;

                          return POSServiceCard(
                            service: service,
                            quantity: quantity,
                            onTap: () => _incrementService(service),
                            onIncrement: () => _incrementService(service),
                            onDecrement: () => _decrementService(service),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right: Customer & Summary - Enhanced UI
        Container(
          width: 400, // Wider panel
          margin: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 1. Customer Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Khách hàng',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (!_isAddingNewCustomer)
                            ElevatedButton.icon(
                              onPressed: () =>
                                  setState(() => _isAddingNewCustomer = true),
                              icon: const Icon(Icons.person_add, size: 18),
                              label: const Text('Thêm mới'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE3F2FD),
                                foregroundColor: const Color(0xFF1565C0),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_isAddingNewCustomer) ...[
                        // Quick add customer form - Larger inputs
                        TextField(
                          controller: _customerNameController,
                          decoration: InputDecoration(
                            labelText: 'Tên khách hàng',
                            prefixIcon: const Icon(
                              Icons.account_circle_outlined,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customerPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Số điện thoại',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => setState(() {
                                  _isAddingNewCustomer = false;
                                  _customerNameController.clear();
                                  _customerPhoneController.clear();
                                }),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  foregroundColor: Colors.grey[700],
                                ),
                                child: const Text('Hủy bỏ'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _quickAddCustomer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1565C0),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Lưu khách hàng'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Customer Searchable Dropdown
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return DropdownMenu<Customer>(
                              width: constraints.maxWidth,
                              enableFilter: true, // Cho phép nhập để tìm kiếm
                              requestFocusOnTap:
                                  true, // Tự động focus khi bấm vào
                              label: const Text(
                                'Tìm khách hàng (Tên hoặc SĐT)',
                              ),
                              inputDecorationTheme: InputDecorationTheme(
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              menuStyle: MenuStyle(
                                backgroundColor: WidgetStateProperty.all(
                                  Colors.white,
                                ),
                                elevation: WidgetStateProperty.all(4),
                                maximumSize: WidgetStateProperty.all(
                                  const Size.fromHeight(300),
                                ),
                              ),
                              dropdownMenuEntries: _customers
                                  .map<DropdownMenuEntry<Customer>>((
                                    Customer customer,
                                  ) {
                                    return DropdownMenuEntry<Customer>(
                                      value: customer,
                                      label:
                                          '${customer.name} - ${customer.phone}',
                                      leadingIcon: const Icon(
                                        Icons.person_outline,
                                      ),
                                      style: ButtonStyle(
                                        padding: WidgetStateProperty.all(
                                          const EdgeInsets.all(12),
                                        ),
                                        textStyle: WidgetStateProperty.all(
                                          const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(),
                              onSelected: (Customer? customer) {
                                setState(() {
                                  _selectedCustomer = customer;
                                });
                              },
                              initialSelection: _selectedCustomer,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Order Details Card (Bill style)
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Store Info Header
                        if (_storeName != null) ...[
                          InkWell(
                            onTap:
                                _showQuickStoreSettingsDialog, // Allow editing by tapping name
                            child: Column(
                              children: [
                                Text(
                                  _storeName!,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (_storeAddress != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _storeAddress!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (_storePhone != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Hotline: $_storePhone',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                        ] else ...[
                          // Button to configure store info
                          InkWell(
                            onTap: _showQuickStoreSettingsDialog,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                border: Border.all(color: Colors.orange[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.store_mall_directory,
                                    color: Colors.orange[800],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cài đặt thông tin cửa hàng',
                                    style: TextStyle(
                                      color: Colors.orange[900],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                        ],

                        // Date Picker
                        InkWell(
                          onTap: _pickDeliveryDateTime,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time_filled,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Hẹn giao đồ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'dd/MM/yyyy • HH:mm',
                                        ).format(_deliveryDate),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.edit,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Divider(height: 32),

                        // Header Bill
                        Row(
                          children: const [
                            Icon(
                              Icons.receipt_long,
                              size: 20,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'CHI TIẾT ĐƠN HÀNG',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // List items
                        Expanded(
                          child: _serviceQuantities.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_shopping_cart,
                                        size: 48,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Chưa chọn dịch vụ nào',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _serviceQuantities.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 16),
                                  itemBuilder: (context, index) {
                                    final entry = _serviceQuantities.entries
                                        .elementAt(index);
                                    final service = _services.firstWhere(
                                      (s) => s.id == entry.key,
                                    );
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            'x${entry.value}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1565C0),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                service.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                currencyFormat.format(
                                                  service.price,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          currencyFormat.format(
                                            service.price * entry.value,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () =>
                                              _decrementService(service),
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.remove_circle_outline,
                                              size: 20,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),

                        const Divider(thickness: 1, height: 32),

                        // Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tổng cộng:',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              currencyFormat.format(_totalAmount),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 3. Create Button
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton.icon(
                  onPressed:
                      _isCreating ||
                          _serviceQuantities.isEmpty ||
                          _selectedCustomer == null
                      ? null
                      : _createOrder,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print, size: 28),
                  label: Text(
                    _isCreating ? 'ĐANG TẠO...' : 'TẠO ĐƠN & IN BILL',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
