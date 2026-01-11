import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/services/auth_service.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import 'common_dialogs.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final bool isLoading;
  
  const MainLayout({
    super.key,
    required this.child,
    required this.title,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
        children: [
            Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.person, size: 20),
                const SizedBox(width: 8),
                Text(
                  AuthService.instance.currentUser?.fullName ?? 'User',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => _handleLogout(context),
                  tooltip: 'Đăng xuất',
                ),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(child: child),
        ],
      ),
      ),
    if (isLoading)
      Container(
        color: Colors.black54,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
  ],
);
  }

  Widget _buildSidebar(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    
    return Container(
      width: 250,
      color: AppTheme.primaryDark,
      child: Column(
        children: [
          // App logo/title
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.local_laundry_service,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Laundry\nManagement',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white24),
          
          // Menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  context: context,
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  route: '/dashboard',
                  isActive: currentRoute == '/dashboard',
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.receipt_long,
                  label: 'Đơn hàng',
                  route: '/orders',
                  isActive: currentRoute == '/orders',
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.people,
                  label: 'Khách hàng',
                  route: '/customers',
                  isActive: currentRoute == '/customers',
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.cleaning_services,
                  label: 'Dịch vụ',
                  route: '/services',
                  isActive: currentRoute == '/services',
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.inventory_2,
                  label: 'Kho',
                  route: '/inventory',
                  isActive: currentRoute == '/inventory',
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.attach_money,
                  label: 'Thu chi',
                  route: '/transactions',
                  isActive: currentRoute == '/transactions',
                ),
                if (AuthService.instance.hasPermission(AppConstants.roleAdmin))
                  _buildMenuItem(
                    context: context,
                    icon: Icons.group,
                    label: 'Người dùng',
                    route: '/users',
                    isActive: currentRoute == '/users',
                  ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.timer,
                  label: 'Chấm công',
                  route: '/shifts',
                  isActive: currentRoute == '/shifts',
                ),

                if (AuthService.instance.hasPermission(AppConstants.roleAdmin))
                  _buildMenuItem(
                    context: context,
                    icon: Icons.account_balance_wallet,
                    label: 'Lương NV',
                    route: '/salaries',
                    isActive: currentRoute == '/salaries',
                  ),
                if (AuthService.instance.hasPermission(AppConstants.roleAdmin))
                  _buildMenuItem(
                    context: context,
                    icon: Icons.inventory_2,
                    label: 'Tài sản',
                    route: '/assets',
                    isActive: currentRoute == '/assets',
                  ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.settings,
                  label: 'Cài đặt',
                  route: '/settings',
                  isActive: currentRoute == '/settings',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      selected: isActive,
      selectedTileColor: Colors.white.withValues(alpha: 0.1),
      onTap: () => context.go(route),
      hoverColor: Colors.white10,
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await CommonDialogs.showConfirm(
      context,
      title: 'Đăng xuất',
      content: 'Bạn có chắc chắn muốn đăng xuất không?',
      confirmText: 'Đăng xuất',
      confirmColor: AppTheme.errorColor,
    );

    if (confirm == true) {
      await AuthService.instance.logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}
