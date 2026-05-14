import 'package:caffe/features/pos/presentation/pos_screen.dart';
import 'package:caffe/features/pos/presentation/widgets/invoice_preview_dialog.dart';
import 'package:caffe/features/pos/application/pos_checkout_service.dart';
import 'package:caffe/features/orders/application/orders_history_providers.dart';
import 'package:caffe/features/orders/presentation/orders_history_screen.dart';
import 'package:caffe/shared/models/category_model.dart';
import 'package:caffe/shared/models/menu_item_model.dart';
import 'package:caffe/shared/models/order_item_model.dart';
import 'package:caffe/shared/models/order_model.dart';
import 'package:caffe/features/reports/application/reports_providers.dart';
import 'package:caffe/features/reports/domain/reports_models.dart';
import 'package:caffe/features/reports/presentation/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ar_EG');
  });

  testWidgets('POS screen does not overflow at desktop size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPos(tester);

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('اختيار الأصناف'), findsOneWidget);
  });

  testWidgets('POS screen does not overflow at tablet size', (tester) async {
    await tester.binding.setSurfaceSize(const Size(820, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPos(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('اختيار الأصناف'), findsOneWidget);
  });

  testWidgets('POS screen uses mobile cart summary on narrow size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPos(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('السلة فارغة'), findsOneWidget);
  });

  testWidgets('invoice preview dialog stays scrollable in a short window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) =>
                            InvoicePreviewDialog(invoice: _invoiceFixture()),
                      ),
                      child: const Text('فتح'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('معاينة الفاتورة'), findsOneWidget);
  });

  testWidgets('orders history does not overflow at narrow width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ordersHistoryProvider.overrideWith(
            (ref) async => [
              OrderModel(
                id: 1,
                orderNumber: 1,
                customerName: 'عميل اختبار طويل الاسم',
                paymentMethod: 'فودافون كاش',
                subtotal: 100,
                total: 114,
                createdAt: DateTime(2026, 5, 8, 17, 30),
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: OrdersHistoryScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('سجل الطلبات'), findsOneWidget);
  });

  testWidgets('reports dashboard charts render at tablet width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(820, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportsDashboardProvider.overrideWith(
            (ref) async => _reportsFixture(),
          ),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ReportsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('اتجاه المبيعات اليومية'), findsOneWidget);
    expect(find.text('تحليل طرق الدفع'), findsOneWidget);
    expect(find.text('الأصناف'), findsOneWidget);
  });
}

Future<void> _pumpPos(WidgetTester tester) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        posCustomerProvider(null).overrideWith((ref) async => null),
        posCategoriesProvider.overrideWith(
          (ref) async => const [CategoryModel(id: 1, name: 'قهوة', icon: '☕')],
        ),
        posMenuItemsProvider.overrideWith(
          (ref) async => [
            for (var i = 0; i < 18; i++)
              MenuItemModel(
                id: i + 1,
                categoryId: 1,
                name: 'صنف $i',
                price: 45.0 + i,
                createdAt: DateTime(2026),
              ),
          ],
        ),
        posVatSettingsProvider.overrideWith(
          (ref) async => (enabled: true, percent: 14.0),
        ),
      ],
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: PosScreen(),
        ),
      ),
    ),
  );
}

SavedOrderInvoice _invoiceFixture() {
  return SavedOrderInvoice(
    cafeName: 'كافيه النيل',
    cafePhone: '01000000000',
    cafeAddress: 'القاهرة، مصر',
    footerMessage: 'شكراً لزيارتكم',
    order: OrderModel(
      id: 1,
      orderNumber: 1,
      customerName: 'عميل اختبار',
      customerPhone: '01012345678',
      tableNumber: '4',
      paymentMethod: 'كاش',
      subtotal: 225,
      discountAmount: 10,
      taxAmount: 30.1,
      total: 245.1,
      createdAt: DateTime(2026, 5, 8, 17, 30),
    ),
    items: const [
      OrderItemModel(
        orderId: 1,
        menuItemId: 1,
        itemName: 'إسبريسو',
        quantity: 2,
        unitPrice: 45,
        total: 90,
      ),
      OrderItemModel(
        orderId: 1,
        menuItemId: 2,
        itemName: 'لاتيه كبير',
        quantity: 3,
        unitPrice: 45,
        total: 135,
      ),
    ],
  );
}

ReportsDashboardData _reportsFixture() {
  const selectedSummary = SalesSummary(
    totalSales: 320,
    orderCount: 3,
    averageOrderValue: 106.67,
    totalVat: 28,
    totalDiscount: 10,
  );
  return ReportsDashboardData(
    todaySummary: selectedSummary,
    monthSummary: selectedSummary,
    selectedSummary: selectedSummary,
    customerCount: 12,
    topPaymentMethod: 'كاش',
    paymentAnalytics: const [
      PaymentAnalytics(
        method: 'كاش',
        orderCount: 2,
        revenue: 220,
        percentage: 66.7,
      ),
      PaymentAnalytics(
        method: 'فيزا',
        orderCount: 1,
        revenue: 100,
        percentage: 33.3,
      ),
      PaymentAnalytics(
        method: 'فودافون كاش',
        orderCount: 0,
        revenue: 0,
        percentage: 0,
      ),
      PaymentAnalytics(
        method: 'إنستا باي',
        orderCount: 0,
        revenue: 0,
        percentage: 0,
      ),
    ],
    topQuantityItems: const [
      ItemAnalytics(itemName: 'إسبريسو', quantity: 4, revenue: 180),
      ItemAnalytics(itemName: 'لاتيه', quantity: 2, revenue: 140),
    ],
    topRevenueItems: const [
      ItemAnalytics(itemName: 'إسبريسو', quantity: 4, revenue: 180),
      ItemAnalytics(itemName: 'لاتيه', quantity: 2, revenue: 140),
    ],
    leastSoldItems: const [
      ItemAnalytics(itemName: 'لاتيه', quantity: 2, revenue: 140),
      ItemAnalytics(itemName: 'إسبريسو', quantity: 4, revenue: 180),
    ],
    dailySalesTrend: [
      DailySalesPoint(
        date: DateTime(2026, 5, 13),
        totalSales: 120,
        orderCount: 1,
      ),
      DailySalesPoint(
        date: DateTime(2026, 5, 14),
        totalSales: 200,
        orderCount: 2,
      ),
    ],
  );
}
