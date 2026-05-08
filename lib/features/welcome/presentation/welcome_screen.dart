import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/repositories/customer_repository.dart';
import '../../../shared/repositories/menu_repository.dart';
import '../../../shared/repositories/order_repository.dart';

final welcomeDashboardProvider = FutureProvider<WelcomeDashboardData>((
  ref,
) async {
  final customers = ref.watch(customerRepositoryProvider);
  final menu = ref.watch(menuRepositoryProvider);
  final orders = ref.watch(orderRepositoryProvider);

  final results = await Future.wait<Object>([
    orders.todaySalesTotal(),
    orders.todayOrdersCount(),
    customers.count(),
    menu.menuItemsCount(),
  ]);

  return WelcomeDashboardData(
    todaySales: results[0] as double,
    todayOrders: results[1] as int,
    customers: results[2] as int,
    menuItems: results[3] as int,
  );
});

class WelcomeDashboardData {
  const WelcomeDashboardData({
    required this.todaySales,
    required this.todayOrders,
    required this.customers,
    required this.menuItems,
  });

  final double todaySales;
  final int todayOrders;
  final int customers;
  final int menuItems;
}

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(welcomeDashboardProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final horizontalPadding = isWide ? 48.0 : 20.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: isWide ? 36 : 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(isWide: isWide),
                        const SizedBox(height: 28),
                        dashboard.when(
                          data: (data) =>
                              _DashboardGrid(data: data, isWide: isWide),
                          loading: () => const _DashboardLoading(),
                          error: (error, stackTrace) =>
                              _DashboardError(error: error),
                        ),
                        const SizedBox(height: 28),
                        _ActionGrid(isWide: isWide),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isWide ? 32 : 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accentBrown.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: isWide ? 76 : 60,
            height: isWide ? 76 : 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryGold,
            ),
            child: Icon(
              Icons.local_cafe_rounded,
              color: AppColors.background,
              size: isWide ? 38 : 30,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'كافيه النيل',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'نظام كاشير كافيه',
                  style: AppTextStyles.muted.copyWith(
                    fontSize: isWide ? 18 : 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.data, required this.isWide});

  final WelcomeDashboardData data;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _DashboardCard(
        title: 'مبيعات اليوم',
        value: AppFormatters.currency(data.todaySales),
        icon: Icons.payments_rounded,
      ),
      _DashboardCard(
        title: 'طلبات اليوم',
        value: data.todayOrders.toString(),
        icon: Icons.receipt_long_rounded,
      ),
      _DashboardCard(
        title: 'العملاء',
        value: data.customers.toString(),
        icon: Icons.groups_rounded,
      ),
      _DashboardCard(
        title: 'الأصناف',
        value: data.menuItems.toString(),
        icon: Icons.restaurant_menu_rounded,
      ),
    ];

    return GridView.count(
      crossAxisCount: isWide ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: isWide ? 1.55 : 1.25,
      children: cards,
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: AppColors.primaryGold, size: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.muted),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 160,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger),
      ),
      child: Text(
        'تعذر تحميل بيانات اللوحة: $error',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionButton(
        label: 'طلب جديد',
        icon: Icons.add_shopping_cart_rounded,
        route: AppRoutes.customerEntry,
        isPrimary: true,
      ),
      _ActionButton(
        label: 'لوحة الإدارة',
        icon: Icons.admin_panel_settings_rounded,
        route: AppRoutes.admin,
      ),
      _ActionButton(
        label: 'سجل الطلبات',
        icon: Icons.history_rounded,
        route: AppRoutes.orders,
      ),
      _ActionButton(
        label: 'التقارير',
        icon: Icons.bar_chart_rounded,
        route: AppRoutes.reports,
      ),
      _ActionButton(
        label: 'الإعدادات',
        icon: Icons.settings_rounded,
        route: AppRoutes.settings,
      ),
    ];

    return GridView.count(
      crossAxisCount: isWide ? 5 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isWide ? 2.1 : 1.75,
      children: actions,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.route,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final String route;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    if (isPrimary) {
      return FilledButton(onPressed: () => context.go(route), child: child);
    }

    return OutlinedButton(onPressed: () => context.go(route), child: child);
  }
}
