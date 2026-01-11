import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../repositories/user_repository.dart';
import '../../core/services/auth_service.dart';
import '../../config/constants.dart';
import '../../widgets/main_layout.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> with SingleTickerProviderStateMixin {
  final _userRepo = UserRepository();
  
  List<User> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedRoleFilter;
  String? _selectedStatusFilter;
  
  // Permission State
  late TabController _tabController;
  final Map<String, List<String>> _rolePermissions = {
    AppConstants.roleAdmin: ['create_order', 'payment', 'cancel_order', 'view_customers', 'edit_customers', 'system_config', 'view_reports'],
    AppConstants.roleManager: ['create_order', 'payment', 'cancel_order', 'view_customers', 'view_reports'],
    AppConstants.roleEmployee: ['create_order', 'payment', 'view_customers'],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
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

  List<User> get _filteredUsers {
    return _users.where((user) {
      final matchesSearch = _searchQuery.isEmpty || 
        user.username.toLowerCase().contains(_searchQuery.toLowerCase()) || 
        user.fullName.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesRole = _selectedRoleFilter == null || user.role == _selectedRoleFilter;
      final matchesStatus = _selectedStatusFilter == null || 
        (_selectedStatusFilter == 'active' ? user.isActive : !user.isActive);

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.hasPermission(AppConstants.roleAdmin)) {
      return const MainLayout(title: 'Quản lý người dùng', child: Center(child: Text('Bạn không có quyền truy cập')));
    }

    return MainLayout(
      title: 'Quản lý & Phân quyền',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quản lý & Phân quyền', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Quản lý tài khoản người dùng và thiết lập quyền hạn chi tiết.', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm người dùng'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel: User List
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.only(left: 24, bottom: 24, right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        // Filters
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Tìm kiếm tài khoản...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                  ),
                                  onChanged: (v) => setState(() => _searchQuery = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: _buildDropdownFilter('Mọi vai trò', AppConstants.userRoles, _selectedRoleFilter, (v) => setState(() => _selectedRoleFilter = v))),
                              const SizedBox(width: 12),
                              Expanded(child: _buildDropdownFilter('Mọi trạng thái', ['active', 'inactive'], _selectedStatusFilter, (v) => setState(() => _selectedStatusFilter = v))),
                            ],
                          ),
                        ),
                        // List Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: Colors.grey[50],
                          child: const Row(
                            children: [
                              Expanded(flex: 3, child: Text('NGƯỜI DÙNG', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 2, child: Text('VAI TRÒ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 2, child: Text('TRẠNG THÁI', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))),
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
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) => _buildUserRow(_filteredUsers[index]),
                              ),
                        ),
                         Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Text('Hiển thị ${_filteredUsers.length} kết quả', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Right Panel: Permissions
                Expanded(
                  flex: 1,
                  child: Container(
                    margin: const EdgeInsets.only(right: 24, bottom: 24, left: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user, color: Colors.blue),
                              const SizedBox(width: 8),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Phân quyền Vai trò', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  Text('Chọn vai trò để cấu hình quyền hạn.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        TabBar(
                          controller: _tabController,
                          labelColor: Colors.blue,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Colors.blue,
                          tabs: const [Tab(text: 'Quản trị viên'), Tab(text: 'Quản lý'), Tab(text: 'Nhân viên')],
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
                              TextButton(onPressed: (){}, child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu cấu hình phân quyền'), backgroundColor: Colors.green));
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
                                child: const Text('Lưu'),
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
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter(String hint, List<String> items, String? value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          isExpanded: true,
          items: [
             const DropdownMenuItem<String>(value: null, child: Text('Tất cả', style: TextStyle(fontSize: 13))),
             ...items.map((e) => DropdownMenuItem(value: e, child: Text( _getLabel(e), style: const TextStyle(fontSize: 13))))
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
  
  String _getLabel(String val) {
    if (val == 'active') return 'Hoạt động';
    if (val == 'inactive') return 'Đã khóa';
    return AppConstants.roleLabels[val] ?? val;
  }

  Widget _buildUserRow(User user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.1),
                  child: Text(user.fullName.substring(0, 1).toUpperCase(), style: TextStyle(color: _getRoleColor(user.role))),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(user.username, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRoleColor(user.role).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(AppConstants.roleLabels[user.role] ?? user.role, style: TextStyle(color: _getRoleColor(user.role), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: user.isActive ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                Text(user.isActive ? 'Hoạt động' : 'Đã khóa', style: TextStyle(color: user.isActive ? Colors.black87 : Colors.grey)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey), onPressed: () => _showAddEditDialog(user)),
        ],
      ),
    );
  }
  
  Color _getRoleColor(String role) {
    switch (role) {
      case AppConstants.roleAdmin: return Colors.blue;
      case AppConstants.roleManager: return Colors.purple;
      case AppConstants.roleEmployee: return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _buildPermissionList(String role) {
    final permissions = _rolePermissions[role] ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPermissionGroup('BÁN HÀNG & THU NGÂN', [
          _buildCheckbox('Tạo đơn hàng mới', 'Cho phép tạo và lưu đơn hàng', permissions.contains('create_order'), (v) => _togglePermission(role, 'create_order')),
          _buildCheckbox('Thanh toán', 'Xử lý thanh toán tiền mặt/chuyển khoản', permissions.contains('payment'), (v) => _togglePermission(role, 'payment')),
          _buildCheckbox('Hủy đơn hàng', 'Cho phép hủy đơn đã tạo', permissions.contains('cancel_order'), (v) => _togglePermission(role, 'cancel_order')),
        ]),
        const SizedBox(height: 16),
        _buildPermissionGroup('KHÁCH HÀNG', [
          _buildCheckbox('Xem danh sách khách', '', permissions.contains('view_customers'), (v) => _togglePermission(role, 'view_customers')),
          _buildCheckbox('Chỉnh sửa thông tin', '', permissions.contains('edit_customers'), (v) => _togglePermission(role, 'edit_customers')),
        ]),
         const SizedBox(height: 16),
        _buildPermissionGroup('HỆ THỐNG', [
          _buildCheckbox('Cấu hình hệ thống', 'Chỉ dành cho Quản trị viên', permissions.contains('system_config'), (v) => _togglePermission(role, 'system_config')),
          _buildCheckbox('Xem báo cáo doanh thu', '', permissions.contains('view_reports'), (v) => _togglePermission(role, 'view_reports')),
        ]),
      ],
    );
  }

  Widget _buildPermissionGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Icon(Icons.shopping_cart, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))]),
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

  Widget _buildCheckbox(String title, String subtitle, bool value, Function(bool?) onChanged) {
    return Column(
      children: [
        CheckboxListTile(
          value: value,
          onChanged: onChanged,
          title: Text(title, style: const TextStyle(fontSize: 14)),
          subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
    final usernameController = TextEditingController(text: user?.username ?? '');
    final passwordController = TextEditingController();
    final fullNameController = TextEditingController(text: user?.fullName ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    String selectedRole = user?.role ?? AppConstants.roleEmployee;
    final formKey = GlobalKey<FormState>();
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEdit ? 'Sửa thông tin' : 'Thêm người dùng'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: fullNameController,
                    decoration: const InputDecoration(labelText: 'Họ và tên *', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Nhập họ tên' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(labelText: 'Tên đăng nhập *', border: OutlineInputBorder()),
                    enabled: !isEdit,
                    validator: (v) => v!.isEmpty ? 'Nhập tên đăng nhập' : null,
                  ),
                   const SizedBox(height: 16),
                  if (!isEdit) ...[
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Mật khẩu *', border: OutlineInputBorder()),
                      validator: (v) => v!.length < 6 ? 'Ít nhất 6 ký tự' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Vai trò', border: OutlineInputBorder()),
                    items: AppConstants.userRoles.map((r) => DropdownMenuItem(value: r, child: Text(AppConstants.roleLabels[r]!))).toList(),
                    onChanged: (v) => setState(() => selectedRole = v!),
                  ),
                   const SizedBox(height: 16),
                   TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()),
                  ),
                   const SizedBox(height: 16),
                   TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Hủy')
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  if (isEdit) {
                    await _userRepo.update(user.copyWith(
                      fullName: fullNameController.text,
                      role: selectedRole,
                      phone: phoneController.text,
                      email: emailController.text,
                    ));
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thành công'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                   if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
                   }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
