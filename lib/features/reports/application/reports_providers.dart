import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/repositories/reports_repository.dart';
import '../domain/reports_models.dart';

final reportsFilterProvider =
    NotifierProvider<ReportsFilterController, ReportFilterState>(
      ReportsFilterController.new,
    );

class ReportsFilterController extends Notifier<ReportFilterState> {
  @override
  ReportFilterState build() => const ReportFilterState();

  void setPreset(ReportDatePreset preset) {
    state = state.copyWith(
      preset: preset,
      clearCustom: preset != ReportDatePreset.custom,
    );
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = ReportFilterState(
      preset: ReportDatePreset.custom,
      customStart: start,
      customEnd: end,
    );
  }
}

final reportsTopLimitProvider =
    NotifierProvider<ReportsTopLimitController, int>(
      ReportsTopLimitController.new,
    );

class ReportsTopLimitController extends Notifier<int> {
  @override
  int build() => 5;

  void setLimit(int limit) {
    state = limit == 10 ? 10 : 5;
  }
}

final reportsDashboardProvider = FutureProvider<ReportsDashboardData>((
  ref,
) async {
  final repository = ref.watch(reportsRepositoryProvider);
  final filter = ref.watch(reportsFilterProvider);
  final topLimit = ref.watch(reportsTopLimitProvider);
  final selectedRange = filter.range();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monthStart = DateTime(now.year, now.month);
  final monthEnd = DateTime(now.year, now.month + 1);

  final todaySummary = await repository.getSalesSummary(
    start: today,
    end: today.add(const Duration(days: 1)),
  );
  final monthSummary = await repository.getSalesSummary(
    start: monthStart,
    end: monthEnd,
  );
  final selectedSummary = await repository.getSalesSummary(
    start: selectedRange.start,
    end: selectedRange.end,
  );
  final customerCount = await repository.getCustomerCount();
  final topPaymentMethod = await repository.getTopPaymentMethod(
    start: selectedRange.start,
    end: selectedRange.end,
  );

  return ReportsDashboardData(
    todaySummary: todaySummary,
    monthSummary: monthSummary,
    selectedSummary: selectedSummary,
    customerCount: customerCount,
    topPaymentMethod: topPaymentMethod,
    paymentAnalytics: await repository.getPaymentAnalytics(
      start: selectedRange.start,
      end: selectedRange.end,
    ),
    topQuantityItems: await repository.getItemAnalytics(
      start: selectedRange.start,
      end: selectedRange.end,
      sort: ItemAnalyticsSort.quantityDesc,
      limit: topLimit,
    ),
    topRevenueItems: await repository.getItemAnalytics(
      start: selectedRange.start,
      end: selectedRange.end,
      sort: ItemAnalyticsSort.revenueDesc,
      limit: topLimit,
    ),
    leastSoldItems: await repository.getItemAnalytics(
      start: selectedRange.start,
      end: selectedRange.end,
      sort: ItemAnalyticsSort.quantityAsc,
      limit: topLimit,
    ),
    dailySalesTrend: await repository.getDailySalesTrend(
      start: selectedRange.start,
      end: selectedRange.end,
    ),
  );
});
