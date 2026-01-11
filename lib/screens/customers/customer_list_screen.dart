import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../models/customer.dart';
import '../../repositories/customer_repository.dart';

import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/inputs.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _customerRepo = CustomerRepository();

  List<Customer> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter =
      'Tất cả'; // 'Tất cả', 'Khách quen', 'Nợ cước', 'Mới gần đây'
  final Set<int> _selectedCustomerIds = {};

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _customerRepo.getAll();
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  List<Customer> get _filteredCustomers {
    var filtered = _customers;

    // 1. Text Search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (c) =>
                c.name.toLowerCase().contains(query) ||
                c.phone.contains(query) ||
                (c.id != null && c.id.toString().contains(query)),
          )
          .toList();
    }

    // 2. Tab Filters
    switch (_selectedFilter) {
      case 'Khách quen':
        filtered = filtered.where((c) => c.orderCount >= 5).toList();
        break;
      case 'Mới gần đây':
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        filtered = filtered
            .where((c) => c.createdAt.isAfter(sevenDaysAgo))
            .toList();
        break;
      // 'Nợ cước' logic requires debt tracking which is not yet implemented
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      title: 'Quản lý khách hàng',
      actions: [
        SecondaryButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chức năng Xuất Excel đang phát triển'),
              ),
            );
          },
          label: 'Xuất Excel',
          icon: Icons.download,
        ),
        const SizedBox(width: 8),
        PrimaryButton(
          onPressed: () => _showAddEditDialog(),
          label: 'Thêm khách hàng',
          icon: Icons.add,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter & Search Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: AppTextField(
                        label: 'Tìm kiếm',
                        hintText: 'Nhập tên, SĐT hoặc mã KH...',
                        prefixIcon: Icons.search,
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bộ lọc',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildFilterButton('Tất cả'),
                              _buildFilterButton('Khách quen'),
                              _buildFilterButton('Mới gần đây'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Main Content Card
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  const SectionHeader(title: 'Danh sách khách hàng'),
                  const Divider(height: 1),

                  // TABLE
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildTable(),
                  ),

                  // FOOTER
                  if (!_isLoading)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Hiển thị ${_filteredCustomers.length} khách hàng',
                            style: AppTheme.bodySmall,
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

  Widget _buildFilterButton(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      // Using GestureDetector to allow full custom container
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (_filteredCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.5,
              child: Icon(
                Icons.supervised_user_circle,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy khách hàng nào',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: DataTable2(
        columnSpacing: 24,
        horizontalMargin: 24,
        minWidth: 1000,
        headingRowHeight: 50,
        dataRowHeight: 72,
        headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
        showCheckboxColumn: true,
        onSelectAll: (val) {
          setState(() {
            if (val == true) {
              _selectedCustomerIds.addAll(_filteredCustomers.map((e) => e.id!));
            } else {
              _selectedCustomerIds.clear();
            }
          });
        },
        columns: [
          DataColumn2(
            label: Text('KHÁCH HÀNG', style: _headerStyle),
            size: ColumnSize.L,
          ),
          DataColumn2(
            label: Text('SỐ ĐIỆN THOẠI', style: _headerStyle),
            size: ColumnSize.M,
          ),
          DataColumn2(
            label: Text('ĐỊA CHỈ', style: _headerStyle),
            size: ColumnSize.L,
          ),
          DataColumn2(
            label: Text('ĐƠN GẦN NHẤT', style: _headerStyle),
            size: ColumnSize.L,
          ),
          DataColumn2(
            label: Text('TỔNG CHI TIÊU', style: _headerStyle),
            size: ColumnSize.S,
            numeric: true,
          ),
          DataColumn2(
            label: Text('THAO TÁC', style: _headerStyle),
            fixedWidth: 100,
          ),
        ],
        rows: _filteredCustomers.map((customer) {
          final isSelected = _selectedCustomerIds.contains(customer.id);
          return DataRow2(
            selected: isSelected,
            onSelectChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedCustomerIds.add(customer.id!);
                } else {
                  _selectedCustomerIds.remove(customer.id!);
                }
              });
            },
            onTap: () => context.go('/customers/${customer.id}'),
            cells: [
              DataCell(_buildCustomerCell(customer)),
              DataCell(Text(customer.phone, style: AppTheme.bodyMedium)),
              DataCell(
                Text(
                  (customer.address?.isNotEmpty == true)
                      ? customer.address!
                      : '-',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DataCell(_buildLastOrderCell(customer)),
              DataCell(
                Text(
                  NumberFormat.currency(
                    locale: 'vi',
                    symbol: 'đ',
                    decimalDigits: 0,
                  ).format(customer.totalSpent),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              DataCell(
                Row(
                  children: [
                    Tooltip(
                      message: "Sửa thông tin",
                      child: IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        color: Colors.grey[600],
                        onPressed: () => _showAddEditDialog(customer),
                      ),
                    ),
                    Tooltip(
                      message: "Xem chi tiết",
                      child: IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        color: Colors.grey[600],
                        onPressed: () =>
                            context.go('/customers/${customer.id}'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: Colors.grey[600],
    letterSpacing: 0.5,
  );

  Widget _buildCustomerCell(Customer customer) {
    // Generate initials
    String initials = '';
    final parts = customer.name.split(' ');
    if (parts.isNotEmpty) {
      initials = parts.last[0].toUpperCase();
      if (parts.length > 1) {
        initials = '${parts.first[0].toUpperCase()}$initials';
      }
    }

    // Simple color hash
    final color =
        Colors.primaries[customer.name.hashCode % Colors.primaries.length];

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Text(
            initials,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                customer.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'ID: KH${customer.id.toString().padLeft(3, '0')}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLastOrderCell(Customer customer) {
    if (customer.lastOrderDate == null) {
      return Text(
        'Chưa có',
        style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic),
      );
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(customer.lastOrderDate!);
    final isToday = DateUtils.isSameDay(
      customer.lastOrderDate!,
      DateTime.now(),
    );

    final status = customer.lastOrderStatus ?? 'unknown';
    // Status Logic
    Color statusColor = Colors.grey;
    String statusLabel = status;

    if (status == AppConstants.orderStatusDelivered) {
      statusColor = Colors.green;
      statusLabel = 'Hoàn thành';
    } else if (status == AppConstants.orderStatusWashing) {
      statusColor = Colors.blue;
      statusLabel = 'Đang giặt';
    } else if (status == AppConstants.orderStatusWashed) {
      statusColor = Colors.teal;
      statusLabel = 'Sẵn sàng';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isToday ? 'Hôm nay' : dateStr,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: statusColor),
            const SizedBox(width: 6),
            Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showAddEditDialog([Customer? customer]) async {
    final isEdit = customer != null;
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final addressController = TextEditingController(
      text: customer?.address ?? '',
    );
    final emailController = TextEditingController(text: customer?.email ?? '');
    final notesController = TextEditingController(text: customer?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Sửa thông tin khách hàng' : 'Thêm khách hàng mới',
                style: AppTheme.heading3,
              ),
              const SizedBox(height: 24),
              Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: nameController,
                              label: 'Tên khách hàng',
                              prefixIcon: Icons.person,
                              validator: (v) =>
                                  v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AppTextField(
                              controller: phoneController,
                              label: 'Số điện thoại',
                              prefixIcon: Icons.phone,
                              keyboardType: TextInputType.phone,
                              validator: (v) =>
                                  v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: addressController,
                        label: 'Địa chỉ',
                        prefixIcon: Icons.location_on,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: emailController,
                        label: 'Email',
                        prefixIcon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: notesController,
                        label: 'Ghi chú',
                        prefixIcon: Icons.note,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SecondaryButton(
                            onPressed: () => Navigator.pop(context),
                            label: 'Hủy bỏ',
                          ),
                          const SizedBox(width: 12),
                          PrimaryButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(context, true);
                              }
                            },
                            label: 'Lưu thông tin',
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
      ),
    );

    if (result == true) {
      final newCustomer = Customer(
        id: customer?.id,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        address: addressController.text.trim(),
        email: emailController.text.trim(),
        notes: notesController.text.trim(),
      );
      isEdit
          ? await _customerRepo.update(newCustomer)
          : await _customerRepo.create(newCustomer);
      _loadCustomers();
    }
  }
}
