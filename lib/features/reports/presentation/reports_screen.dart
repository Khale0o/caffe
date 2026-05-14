import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/repositories/reports_repository.dart';
import '../application/reports_providers.dart';
import '../domain/reports_models.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(reportsDashboardProvider);
    final filter = ref.watch(reportsFilterProvider);
    final topLimit = ref.watch(reportsTopLimitProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والتحليلات'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.welcome),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: 'رجوع',
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1100;
            final isTablet = constraints.maxWidth >= 720;
            final horizontalPadding = isDesktop ? 28.0 : 16.0;

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(reportsDashboardProvider),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  18,
                  horizontalPadding,
                  28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FiltersPanel(filter: filter),
                        const SizedBox(height: 16),
                        dashboardAsync.when(
                          data: (dashboard) => _DashboardContent(
                            dashboard: dashboard,
                            topLimit: topLimit,
                            isDesktop: isDesktop,
                            isTablet: isTablet,
                          ),
                          loading: () => const SizedBox(
                            height: 360,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (error, stackTrace) => _MessageState(
                            icon: Icons.error_outline_rounded,
                            title: 'تعذر تحميل التقارير',
                            subtitle: 'راجع بيانات الطلبات ثم حاول مرة أخرى',
                            action: OutlinedButton.icon(
                              onPressed: () =>
                                  ref.invalidate(reportsDashboardProvider),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ),
                        ),
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

class _FiltersPanel extends ConsumerWidget {
  const _FiltersPanel({required this.filter});

  final ReportFilterState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Panel(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final preset in ReportDatePreset.values)
            ChoiceChip(
              label: Text(preset.label),
              selected: filter.preset == preset,
              onSelected: (_) async {
                if (preset == ReportDatePreset.custom) {
                  await _pickCustomRange(context, ref);
                  return;
                }
                ref.read(reportsFilterProvider.notifier).setPreset(preset);
              },
            ),
          if (filter.preset == ReportDatePreset.custom &&
              filter.customStart != null &&
              filter.customEnd != null)
            _RangePill(start: filter.customStart!, end: filter.customEnd!),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: filter.customStart ?? DateTime(now.year, now.month, now.day),
        end: filter.customEnd ?? DateTime(now.year, now.month, now.day),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked == null) return;
    ref
        .read(reportsFilterProvider.notifier)
        .setCustomRange(picked.start, picked.end);
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({
    required this.dashboard,
    required this.topLimit,
    required this.isDesktop,
    required this.isTablet,
  });

  final ReportsDashboardData dashboard;
  final int topLimit;
  final bool isDesktop;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasOrders = dashboard.selectedSummary.orderCount > 0;
    final cardColumns = isDesktop ? 4 : (isTablet ? 2 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricGrid(
          columns: cardColumns,
          metrics: [
            _MetricData(
              title: 'مبيعات اليوم',
              value: AppFormatters.currency(dashboard.todaySummary.totalSales),
              icon: Icons.today_rounded,
            ),
            _MetricData(
              title: 'مبيعات الشهر',
              value: AppFormatters.currency(dashboard.monthSummary.totalSales),
              icon: Icons.calendar_month_rounded,
            ),
            _MetricData(
              title: 'عدد طلبات اليوم',
              value: dashboard.todaySummary.orderCount.toString(),
              icon: Icons.receipt_long_rounded,
            ),
            _MetricData(
              title: 'عدد طلبات الشهر',
              value: dashboard.monthSummary.orderCount.toString(),
              icon: Icons.inventory_2_rounded,
            ),
            _MetricData(
              title: 'متوسط قيمة الطلب',
              value: AppFormatters.currency(
                dashboard.selectedSummary.averageOrderValue,
              ),
              icon: Icons.trending_up_rounded,
            ),
            _MetricData(
              title: 'إجمالي العملاء',
              value: dashboard.customerCount.toString(),
              icon: Icons.groups_rounded,
            ),
            _MetricData(
              title: 'أكثر طرق الدفع استخداماً',
              value: dashboard.topPaymentMethod,
              icon: Icons.payments_rounded,
            ),
            _MetricData(
              title: 'إجمالي الضريبة والخصومات',
              value:
                  '${AppFormatters.currency(dashboard.selectedSummary.totalVat)} / ${AppFormatters.currency(dashboard.selectedSummary.totalDiscount)}',
              icon: Icons.percent_rounded,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!hasOrders)
          const _MessageState(
            icon: Icons.analytics_outlined,
            title: 'لا توجد بيانات في الفترة المحددة',
            subtitle: 'ستظهر التحليلات بعد حفظ طلبات داخل هذا النطاق',
          )
        else ...[
          _ResponsiveTwoColumn(
            isDesktop: isDesktop,
            first: _Panel(
              title: 'اتجاه المبيعات اليومية',
              child: _SalesTrendChart(points: dashboard.dailySalesTrend),
            ),
            second: _Panel(
              title: 'تحليل طرق الدفع',
              child: _PaymentBreakdownChart(
                payments: dashboard.paymentAnalytics,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Panel(
            title: 'الأصناف',
            trailing: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 5, label: Text('Top 5')),
                ButtonSegment(value: 10, label: Text('Top 10')),
              ],
              selected: {topLimit},
              onSelectionChanged: (value) => ref
                  .read(reportsTopLimitProvider.notifier)
                  .setLimit(value.first),
            ),
            child: _ItemAnalyticsSection(
              topQuantityItems: dashboard.topQuantityItems,
              topRevenueItems: dashboard.topRevenueItems,
              leastSoldItems: dashboard.leastSoldItems,
              isDesktop: isDesktop,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics, required this.columns});

  final List<_MetricData> metrics;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _MetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentBrown.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(metric.icon, color: AppColors.primaryGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  metric.title,
                  style: AppTextStyles.muted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;
}

class _ResponsiveTwoColumn extends StatelessWidget {
  const _ResponsiveTwoColumn({
    required this.isDesktop,
    required this.first,
    required this.second,
  });

  final bool isDesktop;
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      return Column(children: [first, const SizedBox(height: 16), second]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
      ],
    );
  }
}

class _SalesTrendChart extends StatelessWidget {
  const _SalesTrendChart({required this.points});

  final List<DailySalesPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _InlineEmptyState(message: 'لا توجد مبيعات يومية');
    }

    return SizedBox(
      height: 260,
      child: CustomPaint(
        painter: _SalesTrendPainter(points: points),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${_shortDate(points.first.date)} - ${_shortDate(points.last.date)}',
              style: AppTextStyles.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SalesTrendPainter extends CustomPainter {
  _SalesTrendPainter({required this.points});

  final List<DailySalesPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(8, 12, size.width - 16, size.height - 48);
    final axisPaint = Paint()
      ..color = AppColors.accentBrown.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..color = AppColors.primaryGold.withValues(alpha: 0.22);
    final linePaint = Paint()
      ..color = AppColors.primaryGold
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = AppColors.text;

    canvas.drawLine(chartRect.bottomLeft, chartRect.bottomRight, axisPaint);
    for (var i = 1; i <= 3; i++) {
      final y = chartRect.top + chartRect.height * i / 4;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        axisPaint,
      );
    }

    final maxSales = points.fold<double>(
      0,
      (maxValue, point) => math.max(maxValue, point.totalSales),
    );
    if (maxSales <= 0) return;

    final path = Path();
    final area = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? chartRect.center.dx
          : chartRect.left + chartRect.width * i / (points.length - 1);
      final y =
          chartRect.bottom -
          (points[i].totalSales / maxSales) * chartRect.height;
      final point = Offset(x, y);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
        area.moveTo(point.dx, chartRect.bottom);
        area.lineTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
        area.lineTo(point.dx, point.dy);
      }
      canvas.drawCircle(point, 4, dotPaint);
    }
    area.lineTo(
      points.length == 1 ? chartRect.center.dx : chartRect.right,
      chartRect.bottom,
    );
    area.close();
    canvas.drawPath(area, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SalesTrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _PaymentBreakdownChart extends StatelessWidget {
  const _PaymentBreakdownChart({required this.payments});

  final List<PaymentAnalytics> payments;

  @override
  Widget build(BuildContext context) {
    final active = payments.where((payment) => payment.orderCount > 0).toList();
    if (active.isEmpty) {
      return const _InlineEmptyState(message: 'لا توجد طرق دفع في هذه الفترة');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 210,
          child: CustomPaint(painter: _PaymentDonutPainter(payments: active)),
        ),
        const SizedBox(height: 12),
        ...payments.map((payment) => _PaymentRow(payment: payment)),
      ],
    );
  }
}

class _PaymentDonutPainter extends CustomPainter {
  _PaymentDonutPainter({required this.payments});

  final List<PaymentAnalytics> payments;

  @override
  void paint(Canvas canvas, Size size) {
    final total = payments.fold<int>(
      0,
      (sum, payment) => sum + payment.orderCount,
    );
    if (total == 0) return;

    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) / 2 - 12,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    var start = -math.pi / 2;
    for (var i = 0; i < payments.length; i++) {
      final sweep = (payments[i].orderCount / total) * math.pi * 2;
      paint.color = _chartColor(i);
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PaymentDonutPainter oldDelegate) {
    return oldDelegate.payments != payments;
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final PaymentAnalytics payment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _chartColor(
                ReportsRepository.paymentMethods.indexOf(payment.method),
              ),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(payment.method)),
          Text('${payment.orderCount} طلب'),
          const SizedBox(width: 12),
          Text(AppFormatters.currency(payment.revenue)),
          const SizedBox(width: 12),
          Text('${payment.percentage.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }
}

class _ItemAnalyticsSection extends StatelessWidget {
  const _ItemAnalyticsSection({
    required this.topQuantityItems,
    required this.topRevenueItems,
    required this.leastSoldItems,
    required this.isDesktop,
  });

  final List<ItemAnalytics> topQuantityItems;
  final List<ItemAnalytics> topRevenueItems;
  final List<ItemAnalytics> leastSoldItems;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final groups = [
      _ItemGroup(title: 'الأكثر مبيعاً بالكمية', items: topQuantityItems),
      _ItemGroup(title: 'الأعلى إيراداً', items: topRevenueItems),
      _ItemGroup(title: 'الأقل مبيعاً', items: leastSoldItems),
    ];

    if (!isDesktop) {
      return Column(
        children: [
          for (final group in groups) ...[
            _ItemBars(group: group),
            if (group != groups.last) const SizedBox(height: 16),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          Expanded(child: _ItemBars(group: group)),
          if (group != groups.last) const SizedBox(width: 14),
        ],
      ],
    );
  }
}

class _ItemBars extends StatelessWidget {
  const _ItemBars({required this.group});

  final _ItemGroup group;

  @override
  Widget build(BuildContext context) {
    if (group.items.isEmpty) {
      return _InlineEmptyState(message: group.title);
    }
    final maxQuantity = group.items.fold<int>(
      0,
      (maxValue, item) => math.max(maxValue, item.quantity),
    );
    final maxRevenue = group.items.fold<double>(
      0,
      (maxValue, item) => math.max(maxValue, item.revenue),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(group.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        for (final item in group.items)
          _ItemBar(
            item: item,
            maxValue: group.title == 'الأعلى إيراداً'
                ? maxRevenue
                : maxQuantity.toDouble(),
            useRevenue: group.title == 'الأعلى إيراداً',
          ),
      ],
    );
  }
}

class _ItemBar extends StatelessWidget {
  const _ItemBar({
    required this.item,
    required this.maxValue,
    required this.useRevenue,
  });

  final ItemAnalytics item;
  final double maxValue;
  final bool useRevenue;

  @override
  Widget build(BuildContext context) {
    final value = useRevenue ? item.revenue : item.quantity.toDouble();
    final factor = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                useRevenue
                    ? AppFormatters.currency(item.revenue)
                    : '${item.quantity} قطعة',
                style: AppTextStyles.muted,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: factor,
              minHeight: 9,
              backgroundColor: AppColors.background.withValues(alpha: 0.75),
              color: AppColors.primaryGold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemGroup {
  const _ItemGroup({required this.title, required this.items});

  final String title;
  final List<ItemAnalytics> items;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.title, this.trailing});

  final Widget child;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentBrown.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  )
                else
                  const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.date_range_rounded, size: 18),
      label: Text('${_shortDate(start)} - ${_shortDate(end)}'),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppColors.primaryGold),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.muted,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: AppTextStyles.muted,
        textAlign: TextAlign.center,
      ),
    );
  }
}

Color _chartColor(int index) {
  const colors = [
    AppColors.primaryGold,
    AppColors.success,
    Color(0xFF6EA8FE),
    Color(0xFFD982B5),
  ];
  return colors[index < 0 ? 0 : index % colors.length];
}

String _shortDate(DateTime value) {
  return DateFormat('yyyy/MM/dd', 'ar_EG').format(value);
}
