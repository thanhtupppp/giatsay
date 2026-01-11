import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../ui/dialogs.dart';

/// The Shell containing the persistent Sidebar
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for content area
      body: Row(
        children: [
          const AppSidebar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The layout for individual pages (Header + Content)
class DesktopLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final bool isLoading;

  const DesktopLayout({
    super.key,
    required this.child,
    required this.title,
    this.actions,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              _Header(title: title, actions: actions),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const _Header({required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: AppTheme.heading2.copyWith(fontSize: 20)),
          ),
          if (actions != null) ...actions!,
          const SizedBox(width: 16),
          Container(height: 24, width: 1, color: AppTheme.borderColor),
          const SizedBox(width: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Text(
                  user?.fullName.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    user?.fullName ?? 'User',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    user?.role ?? 'Staff',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: const [
                        Icon(
                          Icons.logout,
                          size: 20,
                          color: AppTheme.errorColor,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Đăng xuất',
                          style: TextStyle(color: AppTheme.errorColor),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'logout') {
                    _handleLogout(context);
                  }
                },
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showAppConfirmDialog(
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

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    // Check screen width for responsiveness
    final bool isCompact = MediaQuery.of(context).size.width < 1000;

    return Container(
      width: isCompact ? 70 : 250,
      color: AppTheme.primaryDark,
      child: Column(
        children: [
          // App logo/title
          Container(
            height: 64,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: isCompact ? Alignment.center : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: AppTheme
                  .primaryColor, // Slightly lighter brand color for logo area
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: isCompact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                const Icon(
                  Icons.local_laundry_service,
                  color: Colors.white,
                  size: 28,
                ),
                if (!isCompact) ...[
                  const SizedBox(width: 12),
                  const Text(
                    'LAUNDRY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.point_of_sale,
                  label: 'POS',
                  route: '/pos',
                  isActive: currentRoute == '/pos',
                  isCompact: isCompact,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  route: '/dashboard',
                  isActive: currentRoute == '/dashboard',
                  isCompact: isCompact,
                ),
                _buildGroupHeader('QUẢN LÝ', isCompact),
                _buildMenuItem(
                  context,
                  icon: Icons.receipt_long,
                  label: 'Đơn hàng',
                  route: '/orders',
                  isActive: currentRoute.startsWith('/orders'),
                  isCompact: isCompact,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.people,
                  label: 'Khách hàng',
                  route: '/customers',
                  isActive: currentRoute.startsWith('/customers'),
                  isCompact: isCompact,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.cleaning_services,
                  label: 'Dịch vụ',
                  route: '/services',
                  isActive: currentRoute.startsWith('/services'),
                  isCompact: isCompact,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.inventory_2,
                  label: 'Kho',
                  route: '/inventory',
                  isActive: currentRoute.startsWith('/inventory'),
                  isCompact: isCompact,
                ),
                _buildMenuItem(
                  context,
                  icon: Icons.attach_money,
                  label: 'Thu chi',
                  route: '/transactions',
                  isActive: currentRoute.startsWith('/transactions'),
                  isCompact: isCompact,
                ),

                if (AuthService.instance.hasPermission(
                  AppConstants.roleAdmin,
                )) ...[
                  _buildGroupHeader('ADMIN', isCompact),
                  _buildMenuItem(
                    context,
                    icon: Icons.group,
                    label: 'Người dùng',
                    route: '/users',
                    isActive: currentRoute.startsWith('/users'),
                    isCompact: isCompact,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.account_balance_wallet,
                    label: 'Lương NV',
                    route: '/salaries',
                    isActive: currentRoute.startsWith('/salaries'),
                    isCompact: isCompact,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.category,
                    label: 'Tài sản',
                    route: '/assets',
                    isActive: currentRoute.startsWith('/assets'),
                    isCompact: isCompact,
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.settings,
                    label: 'Cài đặt',
                    route: '/settings',
                    isActive: currentRoute.startsWith('/settings'),
                    isCompact: isCompact,
                  ),
                ],
                _buildGroupHeader('NHÂN VIÊN', isCompact),
                _buildMenuItem(
                  context,
                  icon: Icons.timer,
                  label: 'Chấm công',
                  route: '/shifts',
                  isActive: currentRoute.startsWith('/shifts'),
                  isCompact: isCompact,
                ),
              ],
            ),
          ),

          // Version/Footer
          if (!isCompact)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'v1.0.0',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title, bool isCompact) {
    if (isCompact) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required bool isActive,
    required bool isCompact,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(route),
        child: Container(
          height: 50,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 0 : 24),
          decoration: BoxDecoration(
            border: isActive
                ? const Border(left: BorderSide(color: Colors.white, width: 4))
                : null,
            gradient: isActive
                ? LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: isCompact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.7),
                size: 22,
              ),
              if (!isCompact) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
