import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/customer_entry/presentation/customer_entry_screen.dart';
import '../../features/orders/presentation/orders_history_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/welcome/presentation/welcome_screen.dart';
import '../theme/app_colors.dart';

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
        final customerId = int.tryParse(
          state.uri.queryParameters['customerId'] ?? '',
        );
        return PosScreen(customerId: customerId);
      },
    ),
    GoRoute(
      path: AppRoutes.admin,
      name: 'admin',
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'لوحة الإدارة'),
    ),
    GoRoute(
      path: AppRoutes.reports,
      name: 'reports',
      builder: (context, state) => const _PlaceholderScreen(title: 'التقارير'),
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: 'settings',
      builder: (context, state) => const _PlaceholderScreen(title: 'الإعدادات'),
    ),
    GoRoute(
      path: AppRoutes.orders,
      name: 'orders',
      builder: (context, state) => const OrdersHistoryScreen(),
    ),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.welcome),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: 'رجوع',
        ),
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.accentBrown.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            'سيتم تنفيذ هذه الشاشة في مرحلة لاحقة',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
