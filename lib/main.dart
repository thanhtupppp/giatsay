import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/services/auth_service.dart';
import 'config/theme.dart';
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
import 'core/services/backup_service.dart';
import 'screens/pos/pos_screen.dart';

import 'package:intl/date_symbol_data_local.dart';

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
    return MaterialApp.router(
      title: 'Laundry Management',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
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
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrderListScreen(),
    ),
    GoRoute(
      path: '/orders/create',
      builder: (context, state) => const CreateOrderScreen(),
    ),
    GoRoute(
      path: '/orders/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return OrderDetailScreen(orderId: id);
      },
    ),
    GoRoute(
      path: '/customers',
      builder: (context, state) => const CustomerListScreen(),
    ),
    GoRoute(
      path: '/customers/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return CustomerDetailScreen(customerId: id);
      },
    ),
    GoRoute(
      path: '/services',
      builder: (context, state) => const ServiceListScreen(),
    ),
    GoRoute(
      path: '/users',
      builder: (context, state) => const UserListScreen(),
    ),
    GoRoute(
      path: '/transactions',
      builder: (context, state) => const TransactionListScreen(),
    ),

    GoRoute(
      path: '/salaries',
      builder: (context, state) => const SalaryListScreen(),
    ),
    GoRoute(
      path: '/assets',
      builder: (context, state) => const AssetListScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/inventory',
      builder: (context, state) => const MaterialListScreen(),
    ),
    GoRoute(
      path: '/shifts',
      builder: (context, state) => const TimesheetScreen(),
    ),
  ],
);
