import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../models/material_item.dart';
import '../../repositories/material_repository.dart';
import '../../config/theme.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/inputs.dart';
import '../../widgets/ui/dialogs.dart';

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
        showAppAlertDialog(
          context,
          title: 'Lỗi',
          content: 'Không thể tải danh sách vật tư: $e',
        );
      }
    }
  }

  Future<void> _showAddEditDialog([MaterialItem? material]) async {
    final isEdit = material != null;
    final nameController = TextEditingController(text: material?.name ?? '');
    final unitController = TextEditingController(text: material?.unit ?? '');
    final quantityController = TextEditingController(
      text: material?.quantity.toString() ?? '0',
    );
    final minQuantityController = TextEditingController(
      text: material?.minQuantity.toString() ?? '10',
    );
    final costPriceController = TextEditingController(
      text: material?.costPrice.toString() ?? '0',
    );
    final notesController = TextEditingController(text: material?.notes ?? '');

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(32),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Sửa vật tư' : 'Thêm vật tư mới',
                    style: AppTheme.heading2,
                  ),
                  const SizedBox(height: 24),

                  AppTextField(
                    controller: nameController,
                    label: 'Tên vật tư *',
                    hintText: 'VD: Bột giặt Omo, Nước xả Downy...',
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
                        child: AppTextField(
                          controller: unitController,
                          label: 'Đơn vị tính *',
                          hintText: 'kg, lít, chai...',
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
                        child: AppNumberField(
                          controller: quantityController,
                          label: 'Số lượng ban đầu',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nhập số lượng';
                            }
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
                        child: AppNumberField(
                          controller: costPriceController,
                          label: 'Đơn giá nhập',
                          suffixText: 'đ',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: AppNumberField(
                          controller: minQuantityController,
                          label: 'Mức cảnh báo *',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'vui lòng nhập';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: notesController,
                    label: 'Ghi chú',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SecondaryButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        label: 'Hủy',
                      ),
                      const SizedBox(width: 16),
                      PrimaryButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.of(context).pop(true);
                          }
                        },
                        label: isEdit ? 'Cập nhật' : 'Thêm',
                        icon: Icons.save,
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
      try {
        final newMaterial = MaterialItem(
          id: material?.id,
          name: nameController.text.trim(),
          unit: unitController.text.trim(),
          quantity:
              double.tryParse(quantityController.text.replaceAll(',', '')) ?? 0,
          minQuantity:
              double.tryParse(minQuantityController.text.replaceAll(',', '')) ??
              0,
          costPrice:
              double.tryParse(costPriceController.text.replaceAll(',', '')) ??
              0,
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
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
              content: Text(
                isEdit ? 'Đã cập nhật vật tư' : 'Đã thêm vật tư mới',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          showAppAlertDialog(
            context,
            title: 'Lỗi',
            content: 'Có lỗi xảy ra: $e',
          );
        }
      }
    }
  }

  Future<void> _deleteMaterial(MaterialItem material) async {
    final confirm = await showAppConfirmDialog(
      context,
      title: 'Xóa vật tư',
      content:
          'Bạn có chắc chắn muốn xóa vật tư "${material.name}"? Hành động này không thể hoàn tác.',
      confirmText: 'Xóa',
      confirmColor: AppTheme.errorColor,
    );

    if (confirm == true) {
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
        if (mounted) {
          showAppAlertDialog(
            context,
            title: 'Lỗi',
            content: 'Không thể xóa: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      title: 'Kho & Vật tư',
      actions: [
        PrimaryButton(
          onPressed: () => _showAddEditDialog(),
          icon: Icons.add,
          label: 'Thêm vật tư',
        ),
      ],
      child: Column(
        children: [
          // Filter card
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Tìm kiếm',
                    hintText: 'Tên vật tư...',
                    prefixIcon: Icons.search,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      // Debounce could be added here
                      if (value.isEmpty) {
                        _loadMaterials();
                      }
                    },
                    onFieldSubmitted: (_) => _loadMaterials(),
                  ),
                ),
                const SizedBox(width: 16),
                SecondaryButton(
                  onPressed: _loadMaterials,
                  icon: Icons.refresh,
                  label: 'Làm mới',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
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
                      headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                      columnSpacing: 12,
                      horizontalMargin: 20,
                      minWidth: 800,
                      columns: const [
                        DataColumn2(
                          label: Text(
                            'Tên vật tư',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.L,
                        ),
                        DataColumn2(
                          label: Text(
                            'Đơn vị',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                        ),
                        DataColumn2(
                          label: Text(
                            'Tồn kho',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                        ),
                        DataColumn2(
                          label: Text(
                            'Cảnh báo',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                        ),
                        DataColumn2(
                          label: Text(
                            'Đơn giá',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                          numeric: true,
                        ),
                        DataColumn2(
                          label: Text(
                            'Ghi chú',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.L,
                        ),
                        DataColumn2(
                          label: Text(
                            'Thao tác',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                        ),
                      ],
                      rows: _materials.map((material) {
                        final isLowStock = material.isLowStock;
                        final quantityStyle = TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isLowStock
                              ? AppTheme.errorColor
                              : AppTheme.successColor,
                        );

                        return DataRow2(
                          cells: [
                            DataCell(
                              Text(
                                material.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(Text(material.unit)),
                            DataCell(
                              Row(
                                children: [
                                  Text(
                                    NumberFormat(
                                      '#,###',
                                    ).format(material.quantity),
                                    style: quantityStyle,
                                  ),
                                  if (isLowStock)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.warning,
                                        color: AppTheme.errorColor,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                NumberFormat(
                                  '#,###',
                                ).format(material.minQuantity),
                              ),
                            ),
                            DataCell(
                              Text(
                                NumberFormat.currency(
                                  locale: 'vi',
                                  symbol: 'đ',
                                ).format(material.costPrice),
                              ),
                            ),
                            DataCell(Text(material.notes ?? '-')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showAddEditDialog(material),
                                    tooltip: 'Sửa',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: AppTheme.errorColor,
                                      size: 20,
                                    ),
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
          ),
        ],
      ),
    );
  }
}
