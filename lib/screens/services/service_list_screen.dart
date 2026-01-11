import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/inputs.dart';
import '../../widgets/ui/dialogs.dart';

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  final _serviceRepo = ServiceRepository();

  List<Service> _services = [];
  bool _isLoading = true;
  String? _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final services = await _serviceRepo.getAll(category: _selectedCategory);

      setState(() {
        _services = services;
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

  List<Service> get _filteredServices {
    if (_searchQuery.isEmpty) return _services;

    final query = _searchQuery.toLowerCase();
    return _services.where((service) {
      final name = service.name.toLowerCase();
      final description = (service.description ?? '').toLowerCase();

      return name.contains(query) || description.contains(query);
    }).toList();
  }

  Future<void> _showAddEditDialog([Service? service]) async {
    final isEdit = service != null;
    final nameController = TextEditingController(text: service?.name ?? '');
    final priceController = TextEditingController(
      text: service?.price.toString() ?? '',
    );
    final categoryController = TextEditingController(
      text: service?.category ?? '',
    );
    final descriptionController = TextEditingController(
      text: service?.description ?? '',
    );
    String selectedUnit = service?.unit ?? AppConstants.unitKg;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEdit ? Icons.edit : Icons.local_laundry_service,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          isEdit ? 'Sửa dịch vụ' : 'Thêm dịch vụ mới',
                          style: AppTheme.titleMedium.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Fields
                    AppTextField(
                      controller: nameController,
                      label: 'Tên dịch vụ',
                      prefixIcon: Icons.label_outline,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Vui lòng nhập tên dịch vụ'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: categoryController,
                            label: 'Danh mục',
                            prefixIcon: Icons.category_outlined,
                            hintText: 'VD: Giặt, Ủi...',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppDropdown<String>(
                            label: 'Đơn vị',
                            value: selectedUnit,
                            items: AppConstants.serviceUnits.map((unit) {
                              return DropdownMenuItem(
                                value: unit,
                                child: Text(
                                  AppConstants.serviceUnitLabels[unit] ?? unit,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedUnit = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    AppNumberField(
                      controller: priceController,
                      label: 'Giá',
                      suffixText: 'đ',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập giá';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Giá không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      controller: descriptionController,
                      label: 'Mô tả',
                      prefixIcon: Icons.description_outlined,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SecondaryButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          label: 'Hủy bỏ',
                        ),
                        const SizedBox(width: 16),
                        PrimaryButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              Navigator.of(context).pop(true);
                            }
                          },
                          label: isEdit ? 'Lưu thay đổi' : 'Thêm dịch vụ',
                          icon: Icons.check,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (result == true) {
      try {
        final newService = Service(
          id: service?.id,
          name: nameController.text.trim(),
          category: categoryController.text.trim().isEmpty
              ? null
              : categoryController.text.trim(),
          price: double.parse(priceController.text.trim()),
          unit: selectedUnit,
          description: descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
        );

        if (isEdit) {
          await _serviceRepo.update(newService);
        } else {
          await _serviceRepo.create(newService);
        }

        await _loadServices();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEdit ? 'Đã cập nhật dịch vụ' : 'Đã thêm dịch vụ mới',
              ),
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

    nameController.dispose();
    priceController.dispose();
    categoryController.dispose();
    descriptionController.dispose();
  }

  Future<void> _toggleActiveStatus(Service service) async {
    final newStatus = !service.isActive;
    final action = newStatus ? 'kích hoạt' : 'vô hiệu hóa';

    final confirm = await showAppConfirmDialog(
      context,
      title: 'Xác nhận $action',
      content: 'Bạn có muốn $action dịch vụ "${service.name}" không?',
      confirmText: newStatus ? 'Kích hoạt' : 'Vô hiệu hóa',
      confirmColor: newStatus ? AppTheme.primaryColor : AppTheme.errorColor,
    );

    if (confirm == true) {
      try {
        final newService = service.copyWith(isActive: newStatus);
        await _serviceRepo.update(newService);
        await _loadServices();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newStatus ? 'Đã kích hoạt dịch vụ' : 'Đã vô hiệu hóa dịch vụ',
              ),
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
  }

  @override
  Widget build(BuildContext context) {
    final categories = _services
        .where((s) => s.category != null)
        .map((s) => s.category!)
        .toSet()
        .toList();

    return DesktopLayout(
      title: 'Quản lý dịch vụ',
      actions: [
        PrimaryButton(
          onPressed: () => _showAddEditDialog(),
          icon: Icons.add,
          label: 'Thêm dịch vụ',
        ),
      ],
      child: Column(
        children: [
          // Filter & Search Card
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Tìm kiếm',
                    hintText: 'Nhập tên dịch vụ, mã dịch vụ...',
                    prefixIcon: Icons.search,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Category filter
                if (categories.isNotEmpty)
                  SizedBox(
                    width: 250,
                    child: AppDropdown<String>(
                      label: 'Danh mục',
                      value: _selectedCategory,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tất cả'),
                        ),
                        ...categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                        _loadServices();
                      },
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Grid View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Responsive grid: width > 1200 ? 3 cols : 2 cols
                      int crossAxisCount = constraints.maxWidth > 1200 ? 3 : 2;
                      if (constraints.maxWidth < 800) crossAxisCount = 1;

                      return GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          childAspectRatio: 2.0, // Wider cards
                        ),
                        itemCount: _filteredServices.length,
                        itemBuilder: (context, index) {
                          final service = _filteredServices[index];
                          return _buildServiceCard(service);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Service service) {
    return _ServiceCard(
      service: service,
      onEdit: () => _showAddEditDialog(service),
      onToggle: () => _toggleActiveStatus(service),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  final Service service;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  IconData _getIconForCategory(String? category) {
    if (category == null) return Icons.local_laundry_service;
    final cat = category.toLowerCase();
    if (cat.contains('giặt')) return Icons.local_laundry_service;
    if (cat.contains('ủi') || cat.contains('là')) return Icons.iron;
    if (cat.contains('hấp')) return Icons.dry_cleaning;
    if (cat.contains('giày')) return Icons.hiking;
    return Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onEdit,
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconForCategory(widget.service.category),
                    color: AppTheme.primaryColor,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: widget.service.isActive,
                    onChanged: (value) => widget.onToggle(),
                    activeTrackColor: AppTheme.successColor,
                    inactiveThumbColor: Colors.grey,
                    activeThumbColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.service.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              widget.service.description ?? 'Chưa có mô tả',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      NumberFormat.currency(
                        locale: 'vi',
                        symbol: 'đ',
                        decimalDigits: 0,
                      ).format(widget.service.price),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      ' / ${AppConstants.serviceUnitLabels[widget.service.unit] ?? widget.service.unit}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Sửa'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
