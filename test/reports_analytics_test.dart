import 'dart:io';

import 'package:caffe/core/database/app_database.dart';
import 'package:caffe/features/reports/domain/reports_models.dart';
import 'package:caffe/shared/models/customer_model.dart';
import 'package:caffe/shared/models/order_item_model.dart';
import 'package:caffe/shared/models/order_model.dart';
import 'package:caffe/shared/repositories/customer_repository.dart';
import 'package:caffe/shared/repositories/order_repository.dart';
import 'package:caffe/shared/repositories/reports_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('report date presets calculate expected ranges', () {
    final now = DateTime(2026, 5, 14, 15, 30);

    final today = const ReportFilterState(
      preset: ReportDatePreset.today,
    ).range(now: now);
    final yesterday = const ReportFilterState(
      preset: ReportDatePreset.yesterday,
    ).range(now: now);
    final week = const ReportFilterState(
      preset: ReportDatePreset.thisWeek,
    ).range(now: now);
    final month = const ReportFilterState(
      preset: ReportDatePreset.thisMonth,
    ).range(now: now);
    final allTime = const ReportFilterState(
      preset: ReportDatePreset.allTime,
    ).range(now: now);
    final custom = ReportFilterState(
      preset: ReportDatePreset.custom,
      customStart: DateTime(2026, 5, 3, 12),
      customEnd: DateTime(2026, 5, 6, 18),
    ).range(now: now);

    expect(today.start, DateTime(2026, 5, 14));
    expect(today.end, DateTime(2026, 5, 15));
    expect(yesterday.start, DateTime(2026, 5, 13));
    expect(yesterday.end, DateTime(2026, 5, 14));
    expect(week.start, DateTime(2026, 5, 11));
    expect(week.end, DateTime(2026, 5, 15));
    expect(month.start, DateTime(2026, 5));
    expect(month.end, DateTime(2026, 6));
    expect(allTime.isAllTime, isTrue);
    expect(custom.start, DateTime(2026, 5, 3));
    expect(custom.end, DateTime(2026, 5, 7));
  });

  test('reports repository returns aggregate sales analytics', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'caffe_reports_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDirectory.path,
    );
    addTearDown(() async {
      await AppDatabase.instance.close();
      await tempDirectory.delete(recursive: true);
    });

    final customers = CustomerRepository(AppDatabase.instance);
    final orders = OrderRepository(AppDatabase.instance);
    final reports = ReportsRepository(AppDatabase.instance);
    await customers.create(
      CustomerModel(name: 'عميل أول', phone: '0101', createdAt: DateTime(2026)),
    );
    await customers.create(
      CustomerModel(name: 'عميل ثان', phone: '0102', createdAt: DateTime(2026)),
    );

    await orders.createOrder(
      OrderModel(
        orderNumber: 1,
        paymentMethod: 'كاش',
        subtotal: 100,
        discountAmount: 0,
        taxAmount: 14,
        total: 114,
        createdAt: DateTime(2026, 5, 14, 10),
      ),
      const [
        OrderItemModel(
          orderId: 0,
          menuItemId: 1,
          itemName: 'إسبريسو',
          quantity: 2,
          unitPrice: 50,
          total: 100,
        ),
      ],
    );
    await orders.createOrder(
      OrderModel(
        orderNumber: 2,
        paymentMethod: 'فيزا',
        subtotal: 55,
        discountAmount: 5,
        taxAmount: 0,
        total: 50,
        createdAt: DateTime(2026, 5, 13, 12),
      ),
      const [
        OrderItemModel(
          orderId: 0,
          menuItemId: 2,
          itemName: 'لاتيه',
          quantity: 1,
          unitPrice: 55,
          total: 55,
        ),
      ],
    );
    await orders.createOrder(
      OrderModel(
        orderNumber: 3,
        paymentMethod: 'فودافون كاش',
        subtotal: 30,
        discountAmount: 0,
        taxAmount: 0,
        total: 30,
        createdAt: DateTime(2026, 4, 20, 9),
      ),
      const [
        OrderItemModel(
          orderId: 0,
          menuItemId: 3,
          itemName: 'شاي',
          quantity: 3,
          unitPrice: 10,
          total: 30,
        ),
      ],
    );

    final maySummary = await reports.getSalesSummary(
      start: DateTime(2026, 5),
      end: DateTime(2026, 6),
    );
    final paymentAnalytics = await reports.getPaymentAnalytics(
      start: DateTime(2026, 5),
      end: DateTime(2026, 6),
    );
    final topQuantity = await reports.getItemAnalytics(
      start: DateTime(2026, 5),
      end: DateTime(2026, 6),
      sort: ItemAnalyticsSort.quantityDesc,
      limit: 5,
    );
    final topRevenue = await reports.getItemAnalytics(
      start: DateTime(2026, 5),
      end: DateTime(2026, 6),
      sort: ItemAnalyticsSort.revenueDesc,
      limit: 5,
    );
    final leastSold = await reports.getItemAnalytics(
      start: DateTime(2026, 5),
      end: DateTime(2026, 6),
      sort: ItemAnalyticsSort.quantityAsc,
      limit: 5,
    );
    final trend = await reports.getDailySalesTrend(
      start: DateTime(2026, 5),
      end: DateTime(2026, 6),
    );

    expect(maySummary.totalSales, 164);
    expect(maySummary.orderCount, 2);
    expect(maySummary.averageOrderValue, 82);
    expect(maySummary.totalVat, 14);
    expect(maySummary.totalDiscount, 5);
    expect(await reports.getCustomerCount(), 2);
    expect(
      await reports.getTopPaymentMethod(
        start: DateTime(2026, 5),
        end: DateTime(2026, 6),
      ),
      'كاش',
    );

    final cash = paymentAnalytics.singleWhere((item) => item.method == 'كاش');
    final visa = paymentAnalytics.singleWhere((item) => item.method == 'فيزا');
    final insta = paymentAnalytics.singleWhere(
      (item) => item.method == 'إنستا باي',
    );
    expect(cash.orderCount, 1);
    expect(cash.revenue, 114);
    expect(cash.percentage, 50);
    expect(visa.orderCount, 1);
    expect(insta.orderCount, 0);

    expect(topQuantity.first.itemName, 'إسبريسو');
    expect(topQuantity.first.quantity, 2);
    expect(topRevenue.first.itemName, 'إسبريسو');
    expect(leastSold.first.itemName, 'لاتيه');
    expect(trend.map((point) => point.date), [
      DateTime(2026, 5, 13),
      DateTime(2026, 5, 14),
    ]);
    expect(trend.map((point) => point.totalSales), [50, 114]);
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
