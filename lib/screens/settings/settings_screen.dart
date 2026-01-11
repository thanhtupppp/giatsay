import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/print_service.dart';
import '../../repositories/user_repository.dart';
import '../../models/user.dart';
import '../../models/order.dart';
import '../../models/customer.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../core/services/backup_service.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/inputs.dart';
import '../../widgets/ui/dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _userRepo = UserRepository();
  User? _currentUser;
  bool _isLoading = true;

  // Print settings
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storePhoneController = TextEditingController();
  final _footerMessageController = TextEditingController();
  String _selectedPaperSize = 'roll80';
  bool _autoPrint = false;
  bool _autoBackup = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadSettings();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    _footerMessageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userId = AuthService.instance.currentUser?.id;
      if (userId != null) {
        final user = await _userRepo.getById(userId);
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _storeNameController.text = prefs.getString('store_name') ?? '';
        _storeAddressController.text = prefs.getString('store_address') ?? '';
        _storePhoneController.text = prefs.getString('store_phone') ?? '';
        _footerMessageController.text =
            prefs.getString('print_footer_message') ?? '';
        _selectedPaperSize = prefs.getString('print_paper_size') ?? 'roll80';
        _autoPrint = prefs.getBool('print_auto') ?? false;
        _autoBackup = prefs.getBool('auto_backup') ?? false;

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('store_name', _storeNameController.text);
      await prefs.setString('store_address', _storeAddressController.text);
      await prefs.setString('store_phone', _storePhoneController.text);
      await prefs.setString(
        'print_footer_message',
        _footerMessageController.text,
      );
      await prefs.setString('print_paper_size', _selectedPaperSize);
      await prefs.setBool('print_auto', _autoPrint);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu cấu hình thành công!'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showAppAlertDialog(context, title: 'Lỗi', content: 'Lỗi khi lưu: $e');
      }
    }
  }

  Future<void> _backupDatabase() async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Chọn vị trí lưu backup',
        fileName:
            'laundry_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result != null) {
        await BackupService.instance.backupDatabase(result);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Đã sao lưu database thành công!\n$result'),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showAppAlertDialog(context, title: 'Lỗi', content: 'Lỗi sao lưu: $e');
      }
    }
  }

  Future<void> _restoreDatabase() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Xác nhận khôi phục',
      content:
          'Khôi phục sẽ thay thế toàn bộ dữ liệu hiện tại. Bạn có chắc chắn muốn tiếp tục?',
      confirmText: 'Khôi phục',
      confirmColor: AppTheme.errorColor,
    );

    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Chọn file backup',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result != null && result.files.single.path != null) {
        await BackupService.instance.restoreDatabase(result.files.single.path!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Đã khôi phục database thành công!'),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadCurrentUser();
        }
      }
    } catch (e) {
      if (mounted) {
        showAppAlertDialog(context, title: 'Lỗi', content: 'Lỗi khôi phục: $e');
      }
    }
  }

  Future<void> _previewReceipt() async {
    final dummyOrder = Order(
      id: 0,
      customerId: 0,
      employeeId: 0,
      orderCode: 'TEST-001',
      barcode: '123456789',
      status: AppConstants.orderStatusReceived,
      totalAmount: 150000,
      paidAmount: 50000,
      paymentMethod: AppConstants.paymentCash,
      receivedDate: DateTime.now(),
      deliveryDate: DateTime.now().add(const Duration(days: 1)),
    );

    final dummyCustomer = Customer(
      id: 0,
      name: 'Nguyễn Văn A (Demo)',
      phone: '0912345678',
      address: '123 Đường ABC, Quận XYZ',
    );

    final dummyItems = [
      {
        'service_name': 'Giặt sấy',
        'quantity': 5,
        'unit_price': 15000.0,
        'subtotal': 75000.0,
      },
      {
        'service_name': 'Ủi đồ',
        'quantity': 3,
        'unit_price': 25000.0,
        'subtotal': 75000.0,
      },
    ];

    final storeName = _storeNameController.text;
    final storeAddress = _storeAddressController.text;
    final storePhone = _storePhoneController.text;
    final footerMessage = _footerMessageController.text;

    PdfPageFormat format;
    switch (_selectedPaperSize) {
      case 'a4':
        format = PdfPageFormat.a4;
        break;
      case 'a5':
        format = PdfPageFormat.a5;
        break;
      default:
        format = PdfPageFormat.roll80;
    }

    try {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                AppBar(
                  title: const Text('Xem trước mẫu in'),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.print),
                      tooltip: 'In ngay',
                      onPressed: () async {
                        await Printing.layoutPdf(
                          onLayout: (format) async =>
                              await PrintService.instance.generateOrderReceipt(
                                dummyOrder,
                                dummyCustomer,
                                dummyItems,
                                storeName.isEmpty
                                    ? 'Tên Cửa Hàng Demo'
                                    : storeName,
                                'Admin (Preview)',
                                storeAddress: storeAddress.isEmpty
                                    ? 'Địa chỉ Demo'
                                    : storeAddress,
                                storePhone: storePhone.isEmpty
                                    ? '0909000000'
                                    : storePhone,
                                footerMessage: footerMessage.isEmpty
                                    ? 'Cảm ơn quý khách!'
                                    : footerMessage,
                                pageFormat: format,
                              ),
                        );
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: PdfPreview(
                    build: (pageFormat) async {
                      return PrintService.instance.generateOrderReceipt(
                        dummyOrder,
                        dummyCustomer,
                        dummyItems,
                        storeName.isEmpty ? 'Tên Cửa Hàng Demo' : storeName,
                        'Admin (Preview)',
                        storeAddress: storeAddress.isEmpty
                            ? 'Địa chỉ Demo'
                            : storeAddress,
                        storePhone: storePhone.isEmpty
                            ? '0909000000'
                            : storePhone,
                        footerMessage: footerMessage.isEmpty
                            ? 'Cảm ơn quý khách!'
                            : footerMessage,
                        pageFormat: pageFormat,
                      );
                    },
                    initialPageFormat: format,
                    canChangeOrientation: false,
                    canDebug: false,
                    useActions: false,
                    scrollViewDecoration: BoxDecoration(
                      color: Colors.grey[100],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showAppAlertDialog(context, title: 'Lỗi', content: 'Lỗi xem trước: $e');
      }
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Đổi mật khẩu', style: AppTheme.heading2),
                  const SizedBox(height: 24),

                  AppTextField(
                    controller: currentPasswordController,
                    label: 'Mật khẩu hiện tại *',
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu hiện tại';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: newPasswordController,
                    label: 'Mật khẩu mới *',
                    obscureText: true,
                    prefixIcon: Icons.lock,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu mới';
                      }
                      if (value.length < 6) {
                        return 'Mật khẩu phải có ít nhất 6 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: confirmPasswordController,
                    label: 'Xác nhận mật khẩu *',
                    obscureText: true,
                    prefixIcon: Icons.lock,
                    validator: (value) {
                      if (value != newPasswordController.text) {
                        return 'Mật khẩu không khớp';
                      }
                      return null;
                    },
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
                        label: 'Đổi mật khẩu',
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

    if (result == true && _currentUser != null) {
      try {
        final currentHash = AuthService.instance.hashPasswordPublic(
          currentPasswordController.text,
        );

        if (currentHash != _currentUser!.passwordHash) {
          if (mounted) {
            showAppAlertDialog(
              context,
              title: 'Lỗi',
              content: 'Mật khẩu hiện tại không đúng',
              buttonText: 'Thử lại',
            );
          }
          return;
        }

        final updatedUser = _currentUser!.copyWith(
          passwordHash: AuthService.instance.hashPasswordPublic(
            newPasswordController.text,
          ),
        );
        await _userRepo.update(updatedUser);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã đổi mật khẩu thành công'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          showAppAlertDialog(context, title: 'Lỗi', content: 'Lỗi: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      title: 'Cài đặt',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    title: 'Thông tin tài khoản',
                    icon: Icons.person,
                    children: [
                      _buildInfoRow(
                        'Tên đăng nhập',
                        _currentUser?.username ?? '-',
                      ),
                      _buildInfoRow('Họ tên', _currentUser?.fullName ?? '-'),
                      _buildInfoRow('Vai trò', _currentUser?.role ?? '-'),
                      _buildInfoRow('Email', _currentUser?.email ?? '-'),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        onPressed: _showChangePasswordDialog,
                        icon: Icons.lock_reset,
                        label: 'Đổi mật khẩu',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Print Configuration Section
                  _buildSection(
                    title: 'Cấu hình in ấn',
                    icon: Icons.print,
                    children: [
                      AppTextField(
                        controller: _storeNameController,
                        label: 'Tên cửa hàng',
                        prefixIcon: Icons.store,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _storeAddressController,
                        label: 'Địa chỉ',
                        prefixIcon: Icons.location_on,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _storePhoneController,
                        label: 'Số điện thoại',
                        prefixIcon: Icons.phone,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _footerMessageController,
                        label: 'Lời chào cuối đơn',
                        prefixIcon: Icons.text_fields,
                      ),
                      const SizedBox(height: 16),
                      AppDropdown<String>(
                        label: 'Khổ giấy in',
                        value: _selectedPaperSize,
                        items: const [
                          DropdownMenuItem(
                            value: 'roll80',
                            child: Text('Khổ 80mm (K80)'),
                          ),
                          DropdownMenuItem(value: 'a4', child: Text('Khổ A4')),
                          DropdownMenuItem(value: 'a5', child: Text('Khổ A5')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedPaperSize = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Row(
                          children: [
                            Icon(Icons.print_outlined, color: Colors.grey[600]),
                            const SizedBox(width: 12),
                            Text(
                              'Tự động in sau khi tạo đơn',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        value: _autoPrint,
                        onChanged: (v) => setState(() => _autoPrint = v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SecondaryButton(
                            onPressed: _previewReceipt,
                            icon: Icons.visibility,
                            label: 'Xem mẫu in',
                          ),
                          const SizedBox(width: 12),
                          PrimaryButton(
                            onPressed: _saveSettings,
                            icon: Icons.save,
                            label: 'Lưu cấu hình in',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Database Management Section
                  _buildSection(
                    title: 'Sao lưu & Khôi phục',
                    icon: Icons.backup,
                    children: [
                      Text(
                        'Sao lưu dữ liệu định kỳ để tránh mất mát thông tin',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Sao lưu tự động hàng ngày'),
                        subtitle: const Text(
                          'Sao lưu vào thư mục Documents/LaundryBackups',
                        ),
                        value: _autoBackup,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (bool value) async {
                          setState(() => _autoBackup = value);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('auto_backup', value);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          PrimaryButton(
                            onPressed: _backupDatabase,
                            icon: Icons.download,
                            label: 'Sao lưu',
                            backgroundColor: AppTheme.successColor,
                          ),
                          const SizedBox(width: 12),
                          SecondaryButton(
                            onPressed: _restoreDatabase,
                            icon: Icons.upload,
                            label: 'Khôi phục',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // App Info Section
                  _buildSection(
                    title: 'Thông tin ứng dụng',
                    icon: Icons.info,
                    children: [
                      _buildInfoRow(
                        'Tên ứng dụng',
                        'Laundry Management System',
                      ),
                      _buildInfoRow('Phiên bản', '1.0.0'),
                      _buildInfoRow('Nền tảng', 'Flutter Desktop (Windows)'),
                      _buildInfoRow('Database', 'SQLite'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.successColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Tính năng hoàn thành',
                                  style: AppTheme.bodyLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...[
                              'Quản lý đơn hàng & In mã vạch',
                              'Quản lý khách hàng',
                              'Báo cáo & Thống kê',
                              'Quản lý lương nhân viên',
                              'Quản lý tài sản',
                              'Xuất báo cáo Excel',
                              'Thu chi tài chính',
                              'Sao lưu & Khôi phục',
                            ].map(
                              (feature) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check,
                                      color: AppTheme.successColor,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(feature, style: AppTheme.bodySmall),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // About Section
                  _buildSection(
                    title: 'Về chúng tôi',
                    icon: Icons.business,
                    children: [
                      Text(
                        'Hệ thống quản lý tiệm giặt sấy chuyên nghiệp, '
                        'giúp tối ưu hóa quy trình vận hành và quản lý doanh nghiệp.',
                        style: AppTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '© 2024 Laundry Management System. All rights reserved.',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTheme.heading3.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
