enum ReportDatePreset {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  allTime,
  custom;

  String get label => switch (this) {
    ReportDatePreset.today => 'اليوم',
    ReportDatePreset.yesterday => 'أمس',
    ReportDatePreset.thisWeek => 'هذا الأسبوع',
    ReportDatePreset.thisMonth => 'هذا الشهر',
    ReportDatePreset.allTime => 'كل الوقت',
    ReportDatePreset.custom => 'فترة مخصصة',
  };
}

class ReportDateRange {
  const ReportDateRange({required this.start, required this.end});

  final DateTime? start;
  final DateTime? end;

  bool get isAllTime => start == null && end == null;
}

class ReportFilterState {
  const ReportFilterState({
    this.preset = ReportDatePreset.today,
    this.customStart,
    this.customEnd,
  });

  final ReportDatePreset preset;
  final DateTime? customStart;
  final DateTime? customEnd;

  ReportFilterState copyWith({
    ReportDatePreset? preset,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearCustom = false,
  }) {
    return ReportFilterState(
      preset: preset ?? this.preset,
      customStart: clearCustom ? null : customStart ?? this.customStart,
      customEnd: clearCustom ? null : customEnd ?? this.customEnd,
    );
  }

  ReportDateRange range({DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final today = DateTime(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day,
    );

    return switch (preset) {
      ReportDatePreset.today => ReportDateRange(
        start: today,
        end: today.add(const Duration(days: 1)),
      ),
      ReportDatePreset.yesterday => ReportDateRange(
        start: today.subtract(const Duration(days: 1)),
        end: today,
      ),
      ReportDatePreset.thisWeek => ReportDateRange(
        start: today.subtract(Duration(days: today.weekday - 1)),
        end: today.add(const Duration(days: 1)),
      ),
      ReportDatePreset.thisMonth => ReportDateRange(
        start: DateTime(effectiveNow.year, effectiveNow.month),
        end: DateTime(effectiveNow.year, effectiveNow.month + 1),
      ),
      ReportDatePreset.allTime => const ReportDateRange(start: null, end: null),
      ReportDatePreset.custom => ReportDateRange(
        start: customStart == null
            ? null
            : DateTime(customStart!.year, customStart!.month, customStart!.day),
        end: customEnd == null
            ? null
            : DateTime(customEnd!.year, customEnd!.month, customEnd!.day + 1),
      ),
    };
  }
}

class SalesSummary {
  const SalesSummary({
    required this.totalSales,
    required this.orderCount,
    required this.averageOrderValue,
    required this.totalVat,
    required this.totalDiscount,
  });

  final double totalSales;
  final int orderCount;
  final double averageOrderValue;
  final double totalVat;
  final double totalDiscount;

  static const empty = SalesSummary(
    totalSales: 0,
    orderCount: 0,
    averageOrderValue: 0,
    totalVat: 0,
    totalDiscount: 0,
  );
}

class PaymentAnalytics {
  const PaymentAnalytics({
    required this.method,
    required this.orderCount,
    required this.revenue,
    required this.percentage,
  });

  final String method;
  final int orderCount;
  final double revenue;
  final double percentage;
}

class ItemAnalytics {
  const ItemAnalytics({
    required this.itemName,
    required this.quantity,
    required this.revenue,
  });

  final String itemName;
  final int quantity;
  final double revenue;
}

class DailySalesPoint {
  const DailySalesPoint({
    required this.date,
    required this.totalSales,
    required this.orderCount,
  });

  final DateTime date;
  final double totalSales;
  final int orderCount;
}

class ReportsDashboardData {
  const ReportsDashboardData({
    required this.todaySummary,
    required this.monthSummary,
    required this.selectedSummary,
    required this.customerCount,
    required this.topPaymentMethod,
    required this.paymentAnalytics,
    required this.topQuantityItems,
    required this.topRevenueItems,
    required this.leastSoldItems,
    required this.dailySalesTrend,
  });

  final SalesSummary todaySummary;
  final SalesSummary monthSummary;
  final SalesSummary selectedSummary;
  final int customerCount;
  final String topPaymentMethod;
  final List<PaymentAnalytics> paymentAnalytics;
  final List<ItemAnalytics> topQuantityItems;
  final List<ItemAnalytics> topRevenueItems;
  final List<ItemAnalytics> leastSoldItems;
  final List<DailySalesPoint> dailySalesTrend;
}
