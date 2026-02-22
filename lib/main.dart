import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/services/auth_service.dart';
import 'core/services/backup_service.dart';
import 'config/theme.dart';
import 'widgets/layouts/desktop_layout.dart';

import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/orders/order_list_screen.dart';
import 'screens/orders/create_order_screen.dart';
import 'screens/orders/order_detail_screen.dart';
import 'screens/customers/customer_list_screen.dart';
import 'screens/customers/customer_detail_screen.dart';
import 'screens/services/service_list_screen.dart';
import 'screens/users/user_list_screen.dart';
import 'screens/transactions/transaction_list_screen.dart';
import 'screens/salaries/salary_list_screen.dart';
import 'screens/assets/asset_list_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/inventory/material_list_screen.dart';
import 'screens/timesheets/timesheet_screen.dart';
import 'screens/pos/pos_screen.dart';
import 'screens/reports/shift_report_screen.dart';
import 'screens/reports/admin_revenue_report_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi', null);

  // Check and perform auto-backup if enabled
  BackupService.instance.performAutoBackupIfNeeded();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine the user's preferred locale
    // Start with 'vi' (Vietnamese) as the default
    const locale = Locale('vi');

    return MaterialApp.router(
      title: 'Laundry Management',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      locale: locale,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final isLoggedIn = await AuthService.instance.isLoggedIn();
    final isLoginRoute = state.matchedLocation == '/login';

    if (!isLoggedIn && !isLoginRoute) {
      return '/login';
    }

    if (isLoggedIn && isLoginRoute) {
      return '/dashboard';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/pos', builder: (context, state) => const POSScreen()),
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DashboardScreen()),
        ),
        GoRoute(
          path: '/orders',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: OrderListScreen()),
        ),
        GoRoute(
          path: '/orders/create',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CreateOrderScreen()),
        ),
        GoRoute(
          path: '/orders/:id',
          pageBuilder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return NoTransitionPage(child: OrderDetailScreen(orderId: id));
          },
        ),
        GoRoute(
          path: '/customers',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CustomerListScreen()),
        ),
        GoRoute(
          path: '/customers/:id',
          pageBuilder: (context, state) {
            final id = int.parse(state.pathParameters['id']!);
            return NoTransitionPage(
              child: CustomerDetailScreen(customerId: id),
            );
          },
        ),
        GoRoute(
          path: '/services',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ServiceListScreen()),
        ),
        GoRoute(
          path: '/users',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: UserListScreen()),
        ),
        GoRoute(
          path: '/transactions',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TransactionListScreen()),
        ),
        GoRoute(
          path: '/salaries',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SalaryListScreen()),
        ),
        GoRoute(
          path: '/assets',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AssetListScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
        GoRoute(
          path: '/inventory',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MaterialListScreen()),
        ),
        GoRoute(
          path: '/shifts',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TimesheetScreen()),
        ),
        GoRoute(
          path: '/reports/shift',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ShiftReportScreen()),
        ),
        GoRoute(
          path: '/reports/revenue',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AdminRevenueReportScreen()),
        ),
      ],
    ),
  ],
);
