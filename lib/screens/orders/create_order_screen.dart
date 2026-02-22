import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../models/order_item.dart';
import '../../models/customer.dart';
import '../../models/service.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/service_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/print_service.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/layouts/desktop_layout.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderRepo = OrderRepository();
  final _customerRepo = CustomerRepository();
  final _serviceRepo = ServiceRepository();

  // Form fields
  Customer? _selectedCustomer;
  DateTime _receivedDate = DateTime.now();
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 2));
  TimeOfDay _deliveryTime = const TimeOfDay(
    hour: 17,
    minute: 0,
  ); // Default 5:00 PM
  String _notes = '';
  String _paymentMethod = AppConstants.paymentCash;
  double _paidAmount = 0;

  // Order items
  final List<OrderItemData> _orderItems = [];

  // Data
  List<Customer> _customers = [];
  List<Service> _services = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final customers = await _customerRepo.getAll();
      final services = await _serviceRepo.getAll();

      setState(() {
        _customers = customers;
        _services = services.where((s) => s.isActive).toList();
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

  double get _totalAmount {
    return _orderItems.fold(0, (sum, item) => sum + item.subtotal);
  }

  void _addOrderItem(Service service) {
    setState(() {
      final existingIndex = _orderItems.indexWhere(
        (item) => item.service.id == service.id,
      );

      if (existingIndex >= 0) {
        _orderItems[existingIndex].quantity++;
        _orderItems[existingIndex].subtotal =
            _orderItems[existingIndex].quantity *
            _orderItems[existingIndex].unitPrice;
      } else {
        _orderItems.add(
          OrderItemData(
            service: service,
            quantity: 1,
            unitPrice: service.price,
            subtotal: service.price,
          ),
        );
      }
    });
  }

  void _removeOrderItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
    });
  }

  void _updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      _removeOrderItem(index);
      return;
    }

    setState(() {
      _orderItems[index].quantity = quantity;
      _orderItems[index].subtotal = quantity * _orderItems[index].unitPrice;
    });
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn khách hàng'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng thêm ít nhất một dịch vụ'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      // Create order
      final order = Order(
        orderCode: '', // Will be generated
        barcode: '', // Will be generated
        customerId: _selectedCustomer!.id!,
        employeeId: currentUser.id!,
        status: AppConstants.orderStatusReceived,
        totalAmount: _totalAmount,
        paidAmount: _paidAmount,
        paymentMethod: _paidAmount > 0 ? _paymentMethod : null,
        notes: _notes.isEmpty ? null : _notes,
        receivedDate: _receivedDate,
        deliveryDate: _deliveryDate,
      );

      final items = _orderItems.map((itemData) {
        return OrderItem(
          orderId: 0, // Will be set by repository
          serviceId: itemData.service.id!,
          quantity: itemData.quantity.toDouble(),
          unitPrice: itemData.unitPrice,
          subtotal: itemData.subtotal,
        );
      }).toList();

      final createdOrder = await _orderRepo.createOrderWithCode(order, items);

      // Get order items with service names for receipt
      final orderItemsForPrint = await _orderRepo.getOrderItemsWithServiceName(
        createdOrder.id!,
      );

      // Print 2 bills: 1 receipt for customer, 1 label for clothes
      await PrintService.instance.printDualBills(
        createdOrder,
        _selectedCustomer!,
        orderItemsForPrint,
        AppConstants.appName,
        currentUser.fullName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã tạo đơn hàng và in 2 bill thành công (1 cho khách, 1 dán đồ)',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );

        // Navigate back to order list
        context.go('/orders');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tạo đơn hàng: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _showAddCustomerDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AddCustomerDialog(),
    );

    if (result != null) {
      try {
        final customerId = await _customerRepo.create(
          Customer(
            name: result['name']!,
            phone: result['phone']!,
            address: result['address']?.isEmpty == true
                ? null
                : result['address'],
          ),
        );

        await _loadData();

        // Select the newly created customer
        setState(() {
          _selectedCustomer = _customers.firstWhere((c) => c.id == customerId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Đã thêm khách hàng "${result['name']}"'),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Lỗi: $e')),
                ],
              ),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      title: 'Tạo đơn hàng mới',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side - Service selection
                    Expanded(
                      flex: 2,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Chọn dịch vụ', style: AppTheme.heading3),
                              const SizedBox(height: 16),

                              ..._services.map((service) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(service.name),
                                    subtitle: Text(
                                      '${NumberFormat.currency(locale: 'vi', symbol: 'đ').format(service.price)} / ${AppConstants.serviceUnitLabels[service.unit]}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.add_circle),
                                      color: AppTheme.primaryColor,
                                      onPressed: () => _addOrderItem(service),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Right side - Order details
                    Expanded(
                      flex: 3,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thông tin đơn hàng',
                                style: AppTheme.heading3,
                              ),
                              const SizedBox(height: 16),

                              // Customer selection with autocomplete
                              Row(
                                children: [
                                  Expanded(
                                    child: Autocomplete<Customer>(
                                      optionsBuilder:
                                          (TextEditingValue textEditingValue) {
                                            if (textEditingValue.text.isEmpty) {
                                              return const Iterable<
                                                Customer
                                              >.empty();
                                            }
                                            final query = textEditingValue.text
                                                .toLowerCase();
                                            return _customers.where((customer) {
                                              final name = customer.name
                                                  .toLowerCase();
                                              final phone = customer.phone
                                                  .toLowerCase();
                                              return name.contains(query) ||
                                                  phone.contains(query);
                                            });
                                          },
                                      displayStringForOption: (Customer customer) {
                                        return '${customer.name} - ${customer.phone}';
                                      },
                                      onSelected: (Customer customer) {
                                        setState(() {
                                          _selectedCustomer = customer;
                                        });
                                      },
                                      fieldViewBuilder:
                                          (
                                            BuildContext context,
                                            TextEditingController
                                            textEditingController,
                                            FocusNode focusNode,
                                            VoidCallback onFieldSubmitted,
                                          ) {
                                            // Pre-fill with selected customer
                                            if (_selectedCustomer != null &&
                                                textEditingController
                                                    .text
                                                    .isEmpty) {
                                              textEditingController.text =
                                                  '${_selectedCustomer!.name} - ${_selectedCustomer!.phone}';
                                            }

                                            return TextFormField(
                                              controller: textEditingController,
                                              focusNode: focusNode,
                                              decoration: InputDecoration(
                                                labelText:
                                                    'Tìm khách hàng (tên hoặc SĐT) *',
                                                hintText:
                                                    'Nhập tên hoặc số điện thoại...',
                                                border:
                                                    const OutlineInputBorder(),
                                                prefixIcon: const Icon(
                                                  Icons.person_search,
                                                ),
                                                suffixIcon:
                                                    _selectedCustomer != null
                                                    ? IconButton(
                                                        icon: const Icon(
                                                          Icons.clear,
                                                        ),
                                                        onPressed: () {
                                                          setState(() {
                                                            _selectedCustomer =
                                                                null;
                                                            textEditingController
                                                                .clear();
                                                          });
                                                        },
                                                      )
                                                    : null,
                                              ),
                                              validator: (value) {
                                                if (_selectedCustomer == null) {
                                                  return 'Vui lòng chọn khách hàng hoặc thêm mới';
                                                }
                                                return null;
                                              },
                                            );
                                          },
                                      optionsViewBuilder:
                                          (
                                            BuildContext context,
                                            AutocompleteOnSelected<Customer>
                                            onSelected,
                                            Iterable<Customer> options,
                                          ) {
                                            return Align(
                                              alignment: Alignment.topLeft,
                                              child: Material(
                                                elevation: 4,
                                                child: Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                        maxHeight: 200,
                                                        maxWidth: 400,
                                                      ),
                                                  child: ListView.builder(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    itemCount: options.length,
                                                    itemBuilder:
                                                        (
                                                          BuildContext context,
                                                          int index,
                                                        ) {
                                                          final Customer
                                                          customer = options
                                                              .elementAt(index);
                                                          return ListTile(
                                                            leading: CircleAvatar(
                                                              child: Text(
                                                                customer.name[0]
                                                                    .toUpperCase(),
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                              ),
                                                            ),
                                                            title: Text(
                                                              customer.name,
                                                            ),
                                                            subtitle: Text(
                                                              customer.phone,
                                                            ),
                                                            onTap: () {
                                                              onSelected(
                                                                customer,
                                                              );
                                                            },
                                                          );
                                                        },
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _showAddCustomerDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Thêm'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Dates
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: _receivedDate,
                                          firstDate: DateTime.now().subtract(
                                            const Duration(days: 7),
                                          ),
                                          lastDate: DateTime.now().add(
                                            const Duration(days: 365),
                                          ),
                                        );
                                        if (date != null) {
                                          setState(() {
                                            _receivedDate = date;
                                          });
                                        }
                                      },
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Ngày nhận *',
                                          border: OutlineInputBorder(),
                                          suffixIcon: Icon(
                                            Icons.calendar_today,
                                          ),
                                        ),
                                        child: Text(
                                          DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_receivedDate),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: _deliveryDate,
                                          firstDate: _receivedDate,
                                          lastDate: DateTime.now().add(
                                            const Duration(days: 365),
                                          ),
                                        );
                                        if (date != null) {
                                          setState(() {
                                            _deliveryDate = DateTime(
                                              date.year,
                                              date.month,
                                              date.day,
                                              _deliveryTime.hour,
                                              _deliveryTime.minute,
                                            );
                                          });
                                        }
                                      },
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Ngày giao dự kiến *',
                                          border: OutlineInputBorder(),
                                          suffixIcon: Icon(
                                            Icons.calendar_today,
                                          ),
                                        ),
                                        child: Text(
                                          DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_deliveryDate),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 120,
                                    child: InkWell(
                                      onTap: () async {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: _deliveryTime,
                                          builder: (context, child) {
                                            return MediaQuery(
                                              data: MediaQuery.of(context)
                                                  .copyWith(
                                                    alwaysUse24HourFormat: true,
                                                  ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (time != null) {
                                          setState(() {
                                            _deliveryTime = time;
                                            _deliveryDate = DateTime(
                                              _deliveryDate.year,
                                              _deliveryDate.month,
                                              _deliveryDate.day,
                                              time.hour,
                                              time.minute,
                                            );
                                          });
                                        }
                                      },
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: 'Giờ hẹn',
                                          border: OutlineInputBorder(),
                                          suffixIcon: Icon(
                                            Icons.access_time,
                                            size: 16,
                                          ),
                                        ),
                                        child: Text(
                                          _deliveryTime.format(context),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Order items
                              Text(
                                'Dịch vụ đã chọn',
                                style: AppTheme.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),

                              if (_orderItems.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppTheme.textSecondary,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Chưa có dịch vụ nào',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ..._orderItems.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.service.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  '${NumberFormat.currency(locale: 'vi', symbol: 'đ').format(item.unitPrice)} / ${AppConstants.serviceUnitLabels[item.service.unit]}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                ),
                                                iconSize: 20,
                                                onPressed: () =>
                                                    _updateQuantity(
                                                      index,
                                                      item.quantity - 1,
                                                    ),
                                              ),
                                              SizedBox(
                                                width: 40,
                                                child: Text(
                                                  item.quantity.toString(),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.add_circle_outline,
                                                ),
                                                iconSize: 20,
                                                onPressed: () =>
                                                    _updateQuantity(
                                                      index,
                                                      item.quantity + 1,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 100,
                                            child: Text(
                                              NumberFormat.currency(
                                                locale: 'vi',
                                                symbol: 'đ',
                                              ).format(item.subtotal),
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            iconSize: 20,
                                            color: AppTheme.errorColor,
                                            onPressed: () =>
                                                _removeOrderItem(index),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),

                              const Divider(height: 32),

                              // Payment
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _paymentMethod,
                                      decoration: const InputDecoration(
                                        labelText: 'Phương thức thanh toán',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: AppConstants.paymentMethods.map((
                                        method,
                                      ) {
                                        return DropdownMenuItem(
                                          value: method,
                                          child: Text(
                                            AppConstants
                                                .paymentMethodLabels[method]!,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _paymentMethod = value!;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      decoration: const InputDecoration(
                                        labelText: 'Số tiền đã trả',
                                        border: OutlineInputBorder(),
                                        suffixText: 'đ',
                                      ),
                                      keyboardType: TextInputType.number,
                                      initialValue: _paidAmount.toString(),
                                      onChanged: (value) {
                                        _paidAmount =
                                            double.tryParse(value) ?? 0;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Notes
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Ghi chú',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 2,
                                onChanged: (value) {
                                  _notes = value;
                                },
                              ),
                              const SizedBox(height: 24),

                              // Total and submit
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Tổng tiền:',
                                          style: AppTheme.heading3,
                                        ),
                                        Text(
                                          NumberFormat.currency(
                                            locale: 'vi',
                                            symbol: 'đ',
                                          ).format(_totalAmount),
                                          style: AppTheme.heading2.copyWith(
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_paidAmount > 0) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Đã trả:',
                                            style: AppTheme.bodyMedium,
                                          ),
                                          Text(
                                            NumberFormat.currency(
                                              locale: 'vi',
                                              symbol: 'đ',
                                            ).format(_paidAmount),
                                            style: AppTheme.bodyMedium.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Còn lại:',
                                            style: AppTheme.bodyMedium,
                                          ),
                                          Text(
                                            NumberFormat.currency(
                                              locale: 'vi',
                                              symbol: 'đ',
                                            ).format(
                                              _totalAmount - _paidAmount,
                                            ),
                                            style: AppTheme.bodyMedium.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.errorColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () =>
                                                context.go('/orders'),
                                            child: const Text('Hủy'),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          flex: 2,
                                          child: ElevatedButton.icon(
                                            onPressed: _createOrder,
                                            icon: const Icon(Icons.check),
                                            label: const Text('Tạo đơn hàng'),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                            ),
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class OrderItemData {
  final Service service;
  int quantity;
  double unitPrice;
  double subtotal;

  OrderItemData({
    required this.service,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });
}

class _AddCustomerDialog extends StatefulWidget {
  const _AddCustomerDialog();

  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
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
                      Icons.person_add,
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
                          'Thêm khách hàng mới',
                          style: AppTheme.heading3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nhập thông tin khách hàng',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Tên khách hàng',
                  hintText: 'VD: Nguyễn Văn A',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tên khách hàng';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Số điện thoại',
                  hintText: 'VD: 0987654321',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập số điện thoại';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Địa chỉ (không bắt buộc)',
                  hintText: 'VD: 123 Đường ABC, Quận 1, TP.HCM',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Hủy', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Navigator.of(context).pop({
                          'name': _nameController.text.trim(),
                          'phone': _phoneController.text.trim(),
                          'address': _addressController.text.trim(),
                        });
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text(
                      'Thêm khách hàng',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
