import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_screen.dart';
import '../../features/backup/presentation/backup_screen.dart';
import '../../features/customer_entry/presentation/customer_entry_screen.dart';
import '../../features/orders/presentation/orders_history_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const welcome = '/';
  static const customerEntry = '/customer-entry';
  static const pos = '/pos';
  static const admin = '/admin';
  static const reports = '/reports';
  static const settings = '/settings';
  static const orders = '/orders';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.welcome,
  routes: [
    GoRoute(
      path: AppRoutes.welcome,
      name: 'welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.customerEntry,
      name: 'customerEntry',
      builder: (context, state) => const CustomerEntryScreen(),
    ),
    GoRoute(
      path: AppRoutes.pos,
      name: 'pos',
      builder: (context, state) {
        final parsedCustomerId = int.tryParse(
          state.uri.queryParameters['customerId'] ?? '',
        );
        final customerId = parsedCustomerId != null && parsedCustomerId > 0
            ? parsedCustomerId
            : null;
        return PosScreen(customerId: customerId);
      },
    ),
    GoRoute(
      path: AppRoutes.admin,
      name: 'admin',
      builder: (context, state) => const AdminScreen(),
    ),
    GoRoute(
      path: AppRoutes.reports,
      name: 'reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (context, state) => const BackupScreen(),
    ),
    GoRoute(
      path: AppRoutes.orders,
      name: 'orders',
      builder: (context, state) => const OrdersHistoryScreen(),
    ),
  ],
);
