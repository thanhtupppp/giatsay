import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user.dart';
import '../../repositories/user_repository.dart';
import '../../core/services/auth_service.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/inputs.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen>
    with SingleTickerProviderStateMixin {
  final _userRepo = UserRepository();

  List<User> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedRoleFilter;
  String? _selectedStatusFilter;

  // Permission State
  late TabController _tabController;
  final Map<String, List<String>> _rolePermissions = {
    AppConstants.roleAdmin: [
      'create_order',
      'payment',
      'cancel_order',
      'view_customers',
      'edit_customers',
      'system_config',
      'view_reports',
    ],
    AppConstants.roleManager: [
      'create_order',
      'payment',
      'cancel_order',
      'view_customers',
      'view_reports',
    ],
    AppConstants.roleEmployee: ['create_order', 'payment', 'view_customers'],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
    _loadPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userRepo.getAll();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('role_permissions');
      if (jsonStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          decoded.forEach((key, value) {
            if (_rolePermissions.containsKey(key) && value is List) {
              _rolePermissions[key] = List<String>.from(value);
            }
          });
        });
      }
    } catch (e) {
      // Ignore error, use default
    }
  }

  List<User> get _filteredUsers {
    return _users.where((user) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          user.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.fullName.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesRole =
          _selectedRoleFilter == null || user.role == _selectedRoleFilter;
      final matchesStatus =
          _selectedStatusFilter == null ||
          (_selectedStatusFilter == 'active' ? user.isActive : !user.isActive);

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.hasPermission(AppConstants.roleAdmin)) {
      return const DesktopLayout(
        title: 'Quản lý người dùng',
        child: Center(child: Text('Bạn không có quyền truy cập')),
      );
    }

    return DesktopLayout(
      title: 'Quản lý người dùng',
      actions: [
        PrimaryButton(
          onPressed: () => _showAddEditDialog(),
          icon: Icons.add,
          label: 'Thêm người dùng',
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Panel: User List
          Expanded(
            flex: 2,
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Filters
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        AppTextField(
                          label: 'Tìm kiếm',
                          hintText: 'Nhập tên, tài khoản...',
                          prefixIcon: Icons.search,
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: AppDropdown<String>(
                                label: 'Vai trò',
                                value: _selectedRoleFilter,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Tất cả'),
                                  ),
                                  ...AppConstants.userRoles.map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(
                                        AppConstants.roleLabels[e] ?? e,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedRoleFilter = v),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AppDropdown<String>(
                                label: 'Trạng thái',
                                value: _selectedStatusFilter,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Tất cả'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'active',
                                    child: Text('Hoạt động'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'inactive',
                                    child: Text('Đã khóa'),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedStatusFilter = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // List Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    color: Colors.grey[50],
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'NGƯỜI DÙNG',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'VAI TRÒ',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'TRẠNG THÁI',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(width: 48), // Access Actions width
                      ],
                    ),
                  ),

                  // List Body
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _filteredUsers.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) =>
                                _buildUserRow(_filteredUsers[index]),
                          ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hiển thị ${_filteredUsers.length} kết quả',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Right Panel: Permissions
          Expanded(
            flex: 1,
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.verified_user,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phân quyền',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Cấu hình quyền hạn theo vai trò',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppTheme.primaryColor,
                    tabs: const [
                      Tab(text: 'Quản trị'),
                      Tab(text: 'Quản lý'),
                      Tab(text: 'Nhân viên'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPermissionList(AppConstants.roleAdmin),
                        _buildPermissionList(AppConstants.roleManager),
                        _buildPermissionList(AppConstants.roleEmployee),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        PrimaryButton(
                          onPressed: () async {
                            try {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setString(
                                'role_permissions',
                                jsonEncode(_rolePermissions),
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã lưu cấu hình phân quyền'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi lưu cấu hình: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          label: 'Lưu cấu hình',
                          icon: Icons.save,
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

  Widget _buildUserRow(User user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(
                    user.role,
                  ).withValues(alpha: 0.1),
                  child: Text(
                    user.fullName.substring(0, 1).toUpperCase(),
                    style: TextStyle(color: _getRoleColor(user.role)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user.username,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getRoleColor(user.role).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  AppConstants.roleLabels[user.role] ?? user.role,
                  style: TextStyle(
                    color: _getRoleColor(user.role),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: user.isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  user.isActive ? 'Hoạt động' : 'Đã khóa',
                  style: TextStyle(
                    color: user.isActive ? Colors.black87 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
            onPressed: () => _showAddEditDialog(user),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case AppConstants.roleAdmin:
        return Colors.blue;
      case AppConstants.roleManager:
        return Colors.purple;
      case AppConstants.roleEmployee:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPermissionList(String role) {
    final permissions = _rolePermissions[role] ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPermissionGroup('BÁN HÀNG & THU NGÂN', [
          _buildCheckbox(
            'Tạo đơn hàng mới',
            'Cho phép tạo và lưu đơn hàng',
            permissions.contains('create_order'),
            (v) => _togglePermission(role, 'create_order'),
          ),
          _buildCheckbox(
            'Thanh toán',
            'Xử lý thanh toán tiền mặt/chuyển khoản',
            permissions.contains('payment'),
            (v) => _togglePermission(role, 'payment'),
          ),
          _buildCheckbox(
            'Hủy đơn hàng',
            'Cho phép hủy đơn đã tạo',
            permissions.contains('cancel_order'),
            (v) => _togglePermission(role, 'cancel_order'),
          ),
        ]),
        const SizedBox(height: 16),
        _buildPermissionGroup('KHÁCH HÀNG', [
          _buildCheckbox(
            'Xem danh sách khách',
            '',
            permissions.contains('view_customers'),
            (v) => _togglePermission(role, 'view_customers'),
          ),
          _buildCheckbox(
            'Chỉnh sửa thông tin',
            '',
            permissions.contains('edit_customers'),
            (v) => _togglePermission(role, 'edit_customers'),
          ),
        ]),
        const SizedBox(height: 16),
        _buildPermissionGroup('HỆ THỐNG', [
          _buildCheckbox(
            'Cấu hình hệ thống',
            'Chỉ dành cho Quản trị viên',
            permissions.contains('system_config'),
            (v) => _togglePermission(role, 'system_config'),
          ),
          _buildCheckbox(
            'Xem báo cáo doanh thu',
            '',
            permissions.contains('view_reports'),
            (v) => _togglePermission(role, 'view_reports'),
          ),
        ]),
      ],
    );
  }

  Widget _buildPermissionGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shopping_cart, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildCheckbox(
    String title,
    String subtitle,
    bool value,
    Function(bool?) onChanged,
  ) {
    return Column(
      children: [
        CheckboxListTile(
          value: value,
          onChanged: onChanged,
          title: Text(title, style: const TextStyle(fontSize: 14)),
          subtitle: subtitle.isNotEmpty
              ? Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                )
              : null,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          activeColor: AppTheme.primaryColor,
        ),
        const Divider(height: 1),
      ],
    );
  }

  void _togglePermission(String role, String perm) {
    setState(() {
      final perms = _rolePermissions[role]!;
      if (perms.contains(perm)) {
        perms.remove(perm);
      } else {
        perms.add(perm);
      }
    });
  }

  Future<void> _showAddEditDialog([User? user]) async {
    final isEdit = user != null;
    final usernameController = TextEditingController(
      text: user?.username ?? '',
    );
    final passwordController = TextEditingController();
    final fullNameController = TextEditingController(
      text: user?.fullName ?? '',
    );
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    String selectedRole = user?.role ?? AppConstants.roleEmployee;
    final formKey = GlobalKey<FormState>();

    await showDialog(
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
                    Text(
                      isEdit ? 'Sửa thông tin' : 'Thêm người dùng',
                      style: AppTheme.titleMedium,
                    ),
                    const SizedBox(height: 24),

                    AppTextField(
                      controller: fullNameController,
                      label: 'Họ và tên',
                      prefixIcon: Icons.person,
                      validator: (v) => v!.isEmpty ? 'Nhập họ tên' : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: usernameController,
                      label: 'Tên đăng nhập',
                      prefixIcon: Icons.account_circle,
                      readOnly: isEdit,
                      validator: (v) =>
                          v!.isEmpty ? 'Nhập tên đăng nhập' : null,
                    ),
                    const SizedBox(height: 16),
                    if (!isEdit) ...[
                      AppTextField(
                        controller: passwordController,
                        label: 'Mật khẩu',
                        prefixIcon: Icons.lock,
                        obscureText: true,
                        validator: (v) =>
                            v!.length < 6 ? 'Ít nhất 6 ký tự' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    AppDropdown<String>(
                      label: 'Vai trò',
                      value: selectedRole,
                      items: AppConstants.userRoles
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(AppConstants.roleLabels[r]!),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedRole = v!),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: phoneController,
                      label: 'Số điện thoại',
                      prefixIcon: Icons.phone,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: emailController,
                      label: 'Email',
                      prefixIcon: Icons.email,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SecondaryButton(
                          onPressed: () => Navigator.pop(context),
                          label: 'Hủy',
                        ),
                        const SizedBox(width: 16),
                        PrimaryButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            try {
                              if (isEdit) {
                                await _userRepo.update(
                                  user.copyWith(
                                    fullName: fullNameController.text,
                                    role: selectedRole,
                                    phone: phoneController.text,
                                    email: emailController.text,
                                  ),
                                );
                              } else {
                                await AuthService.instance.register(
                                  username: usernameController.text,
                                  password: passwordController.text,
                                  fullName: fullNameController.text,
                                  role: selectedRole,
                                  phone: phoneController.text,
                                  email: emailController.text,
                                );
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                                _loadUsers();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Thành công'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          label: 'Lưu',
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
  }
}
