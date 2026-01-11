import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/service.dart';
import '../../repositories/service_repository.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/common_dialogs.dart';

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
    final priceController = TextEditingController(text: service?.price.toString() ?? '');
    final categoryController = TextEditingController(text: service?.category ?? '');
    final descriptionController = TextEditingController(text: service?.description ?? '');
    String selectedUnit = service?.unit ?? AppConstants.unitKg;
    final formKey = GlobalKey<FormState>();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    _buildTextField(
                      controller: nameController,
                      label: 'Tên dịch vụ',
                      icon: Icons.label_outline,
                      isRequired: true,
                      validator: (value) => 
                        (value == null || value.isEmpty) ? 'Vui lòng nhập tên dịch vụ' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: categoryController,
                            label: 'Danh mục',
                            icon: Icons.category_outlined,
                            hintText: 'VD: Giặt, Ủi...',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Đơn vị *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: selectedUnit,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.scale_outlined, color: Colors.grey[600], size: 20),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                items: AppConstants.serviceUnits.map((unit) {
                                  return DropdownMenuItem(
                                    value: unit,
                                    child: Text(AppConstants.serviceUnitLabels[unit] ?? unit),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedUnit = value!;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: priceController,
                      label: 'Giá',
                      icon: Icons.attach_money,
                      isRequired: true,
                      keyboardType: TextInputType.number,
                      suffixText: 'đ',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Vui lòng nhập giá';
                        if (double.tryParse(value) == null) return 'Giá không hợp lệ';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: descriptionController,
                      label: 'Mô tả',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                          child: const Text('Hủy bỏ'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              Navigator.of(context).pop(true);
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: Text(isEdit ? 'Lưu thay đổi' : 'Thêm dịch vụ'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
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
      ),
    );
    
    if (result == true) {
      try {
        final newService = Service(
          id: service?.id,
          name: nameController.text.trim(),
          category: categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
          price: double.parse(priceController.text.trim()),
          unit: selectedUnit,
          description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
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
              content: Text(isEdit ? 'Đã cập nhật dịch vụ' : 'Đã thêm dịch vụ mới'),
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
    
    final confirm = await CommonDialogs.showConfirm(
      context,
      title: 'Xác nhận $action',
      content: 'Bạn có muốn $action dịch vụ "${service.name}" không?',
      confirmText: newStatus ? 'Kích hoạt' : 'Vô hiệu hóa',
      confirmColor: newStatus ? AppTheme.successColor : AppTheme.errorColor,
    );

    if (confirm) {
      try {
        final newService = service.copyWith(isActive: newStatus);
        await _serviceRepo.update(newService);
        await _loadServices();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus ? 'Đã kích hoạt dịch vụ' : 'Đã vô hiệu hóa dịch vụ'),
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
    
    return MainLayout(
      title: 'Quản lý dịch vụ & Giá cả',
      child: Column(
        children: [
          // Filters and search
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm dịch vụ, mã dịch vụ...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
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
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        hintText: 'Tất cả loại dịch vụ',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tất cả loại dịch vụ'),
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
                const SizedBox(width: 16),
                
                // Info text
                Text(
                  'Hiển thị ${_filteredServices.length} dịch vụ',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
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
                        padding: const EdgeInsets.all(24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          childAspectRatio: 1.5, // Aspect ratio for card shape
                          mainAxisExtent: 220, // Fixed height for consistency
                        ),
                        itemCount: _filteredServices.length + 1, // +1 for Add Card
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildAddServiceCard();
                          }
                          final service = _filteredServices[index - 1];
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = false,
    String? hintText,
    String? suffixText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label${isRequired ? ' *' : ''}',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText ?? 'Nhập $label...',
            suffixText: suffixText,
            prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildAddServiceCard() {
    return InkWell(
      onTap: () => _showAddEditDialog(),
      onHover: (value) {}, // Handle hover if needed
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            style: BorderStyle.solid, 
          ),
        ),
        child: DottedBorderPlaceholder(
          onTap: () => _showAddEditDialog(),
        ),
      ),
    );
  }

  Widget _buildServiceCard(Service service) {
    return _ServiceCard(
        service: service,
        onEdit: () => _showAddEditDialog(service),
        onToggle: () => _toggleActiveStatus(service),
        onDelete: () {}, // Optional: Add delete if needed
    );
  }
}

class DottedBorderPlaceholder extends StatelessWidget {
  final VoidCallback onTap;

  const DottedBorderPlaceholder({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Custom painting for dashed border or use a library. 
    // Here effectively using a visual approximation or specific styling.
    // For simplicity, using a Container with simple border but logic suggests looking like dashed.
    // Since we don't have dotted_border package, we'll use a styled container.
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 2), // Solid for now, or use Dashed path if critical
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add, size: 32, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tạo dịch vụ mới',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Thiết lập bảng giá tùy chỉnh',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  final Service service;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _isHovered = false;

  IconData _getIconForCategory(String? category) {
    if (category == null) return Icons.local_laundry_service;
    final cat = category.toLowerCase();
    if (cat.contains('giặt')) return Icons.local_laundry_service;
    if (cat.contains('ủi') || cat.contains('là')) return Icons.iron;
    if (cat.contains('hấp')) return Icons.dry_cleaning;
    if (cat.contains('giày')) return Icons.hiking; // Better icon for shoes?
    return Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? AppTheme.primaryColor.withValues(alpha: 0.5) : Colors.grey[200]!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.1 : 0.05),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                widget.service.description ?? 'Chưa có mô tả',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
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
                        NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0)
                            .format(widget.service.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        ' / ${AppConstants.serviceUnitLabels[widget.service.unit] ?? widget.service.unit}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Sửa'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
