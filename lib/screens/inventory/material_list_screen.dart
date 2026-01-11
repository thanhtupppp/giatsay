import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../models/material_item.dart';
import '../../repositories/material_repository.dart';
import '../../config/theme.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/common_dialogs.dart';

class MaterialListScreen extends StatefulWidget {
  const MaterialListScreen({super.key});

  @override
  State<MaterialListScreen> createState() => _MaterialListScreenState();
}

class _MaterialListScreenState extends State<MaterialListScreen> {
  final _materialRepo = MaterialRepository();
  
  List<MaterialItem> _materials = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }
  
  Future<void> _loadMaterials() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final materials = await _materialRepo.getAll(query: _searchQuery);
      
      setState(() {
        _materials = materials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        CommonDialogs.showError(context, e);
      }
    }
  }
  
  Future<void> _showAddEditDialog([MaterialItem? material]) async {
    final isEdit = material != null;
    final nameController = TextEditingController(text: material?.name ?? '');
    final unitController = TextEditingController(text: material?.unit ?? '');
    final quantityController = TextEditingController(text: material?.quantity.toString() ?? '0');
    final minQuantityController = TextEditingController(text: material?.minQuantity.toString() ?? '10');
    final costPriceController = TextEditingController(text: material?.costPrice.toString() ?? '0');
    final notesController = TextEditingController(text: material?.notes ?? '');
    
    final formKey = GlobalKey<FormState>();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Sửa vật tư' : 'Thêm vật tư mới'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên vật tư *',
                    border: OutlineInputBorder(),
                    hintText: 'VD: Bột giặt Omo, Nước xả Downy...',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập tên vật tư';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: unitController,
                        decoration: const InputDecoration(
                          labelText: 'Đơn vị tính *',
                          border: OutlineInputBorder(),
                          hintText: 'kg, lít, chai, cái...',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập ĐVT';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Số lượng ban đầu',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Nhập số lượng';
                          if (double.tryParse(value) == null) return 'Sai định dạng';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                     Expanded(
                      child: TextFormField(
                        controller: costPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Đơn giá nhập',
                          border: OutlineInputBorder(),
                          suffixText: 'đ',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Nhập đơn giá';
                          if (double.tryParse(value) == null) return 'Sai định dạng';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: minQuantityController,
                        decoration: const InputDecoration(
                          labelText: 'Mức cảnh báo *',
                          border: OutlineInputBorder(),
                          helperText: 'Cảnh báo khi SL <= mức này',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Nhập mức cảnh báo';
                          if (double.tryParse(value) == null) return 'Sai định dạng';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: Text(isEdit ? 'Cập nhật' : 'Thêm'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      try {
        final newMaterial = MaterialItem(
          id: material?.id,
          name: nameController.text.trim(),
          unit: unitController.text.trim(),
          quantity: double.parse(quantityController.text.trim()),
          minQuantity: double.parse(minQuantityController.text.trim()),
          costPrice: double.parse(costPriceController.text.trim()),
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
          createdAt: material?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        if (isEdit) {
          await _materialRepo.update(newMaterial);
        } else {
          await _materialRepo.create(newMaterial);
        }
        
        await _loadMaterials();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEdit ? 'Đã cập nhật vật tư' : 'Đã thêm vật tư mới'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          CommonDialogs.showError(context, e);
        }
      }
    }
    
    nameController.dispose();
    unitController.dispose();
    quantityController.dispose();
    minQuantityController.dispose();
    costPriceController.dispose();
    notesController.dispose();
  }
  
  Future<void> _deleteMaterial(MaterialItem material) async {
    final confirm = await CommonDialogs.showDeleteConfirmation(
      context,
      title: 'Xóa vật tư',
      content: 'Bạn có chắc chắn muốn xóa vật tư "${material.name}"? Hành động này không thể hoàn tác.',
    );
    
    if (confirm) {
      try {
        await _materialRepo.delete(material.id!);
        await _loadMaterials();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa vật tư'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) CommonDialogs.showError(context, e);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Kho & Vật tư',
      child: Column(
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Tìm kiếm',
                      hintText: 'Tên vật tư...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      // Debounce could be added here
                      if (value.isEmpty) _loadMaterials();
                    },
                    onSubmitted: (_) => _loadMaterials(),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm vật tư'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Data Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _materials.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Kho trống',
                              style: AppTheme.bodyLarge.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : DataTable2(
                        columnSpacing: 12,
                        horizontalMargin: 12,
                        minWidth: 800,
                        columns: const [
                          DataColumn2(label: Text('Tên vật tư'), size: ColumnSize.L),
                          DataColumn2(label: Text('Đơn vị'), size: ColumnSize.S),
                          DataColumn2(label: Text('Tồn kho'), size: ColumnSize.S),
                          DataColumn2(label: Text('Cảnh báo'), size: ColumnSize.S),
                          DataColumn2(label: Text('Đơn giá'), size: ColumnSize.M),
                          DataColumn2(label: Text('Ghi chú'), size: ColumnSize.L),
                          DataColumn2(label: Text('Thao tác'), size: ColumnSize.S),
                        ],
                        rows: _materials.map((material) {
                            final isLowStock = material.isLowStock;
                            final quantityStyle = TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isLowStock ? AppTheme.errorColor : AppTheme.successColor,
                            );

                          return DataRow2(
                            cells: [
                              DataCell(Text(material.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              DataCell(Text(material.unit)),
                              DataCell(
                                Row(
                                    children: [
                                        Text(
                                            NumberFormat('#,###').format(material.quantity),
                                            style: quantityStyle,
                                        ),
                                        if (isLowStock)
                                            const Padding(
                                                padding: EdgeInsets.only(left: 4),
                                                child: Icon(Icons.warning, color: AppTheme.errorColor, size: 16),
                                            )
                                    ]
                                )
                              ),
                              DataCell(Text(NumberFormat('#,###').format(material.minQuantity))),
                              DataCell(Text(NumberFormat.currency(locale: 'vi', symbol: 'đ').format(material.costPrice))),
                              DataCell(Text(material.notes ?? '-')),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      iconSize: 20,
                                      onPressed: () => _showAddEditDialog(material),
                                      tooltip: 'Sửa',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      iconSize: 20,
                                      color: AppTheme.errorColor,
                                      onPressed: () => _deleteMaterial(material),
                                      tooltip: 'Xóa',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}
