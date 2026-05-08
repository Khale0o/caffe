import 'dart:convert';
import 'dart:io';

import 'package:caffe/features/invoices/application/invoice_pdf_service.dart';
import 'package:caffe/features/pos/application/pos_checkout_service.dart';
import 'package:caffe/shared/models/order_item_model.dart';
import 'package:caffe/shared/models/order_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ar_EG');
  });

  test('loads bundled Arabic font', () async {
    final service = InvoicePdfService();

    final font = await service.loadArabicFont();

    expect(font, isNotNull);
  });

  test(
    'generates Arabic invoice PDF with embedded unicode font data',
    () async {
      final service = InvoicePdfService();

      final bytes = await service.generateInvoicePdf(_invoiceFixture());
      final pdfText = latin1.decode(bytes, allowInvalid: true);

      expect(bytes.length, greaterThan(1000));
      expect(pdfText.startsWith('%PDF'), isTrue);
      expect(pdfText.contains('/ToUnicode'), isTrue);
      expect(pdfText.contains('/FontFile2'), isTrue);
    },
  );

  test('creates padded invoice file names', () {
    const service = InvoicePdfService();

    expect(service.invoiceFileName(1), 'invoice_0001.pdf');
    expect(service.invoiceFileName(42), 'invoice_0042.pdf');
    expect(service.invoiceFileName(1200), 'invoice_1200.pdf');
  });

  test('exports invoice PDF inside app documents directory', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'caffe_pdf_export_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDirectory.path,
    );
    addTearDown(() => tempDirectory.delete(recursive: true));
    final service = InvoicePdfService();

    final path = await service.exportInvoicePdf(_invoiceFixture());
    final file = File(path);

    expect(path, endsWith('invoice_0007.pdf'));
    expect(path, startsWith(tempDirectory.path));
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(1000));
  });
}

SavedOrderInvoice _invoiceFixture() {
  return SavedOrderInvoice(
    cafeName: 'كافيه النيل',
    cafePhone: '01000000000',
    cafeAddress: 'القاهرة، مصر',
    footerMessage: 'شكراً لزيارتكم',
    order: OrderModel(
      id: 7,
      orderNumber: 7,
      customerName: 'منى سعيد',
      customerPhone: '01099998888',
      tableNumber: '3',
      paymentMethod: 'كاش',
      subtotal: 125,
      discountValue: 10,
      discountType: 'percent',
      discountAmount: 12.5,
      taxAmount: 15.75,
      total: 128.25,
      createdAt: DateTime(2026, 5, 8, 17, 30),
    ),
    items: const [
      OrderItemModel(
        orderId: 7,
        menuItemId: 1,
        itemName: 'إسبريسو',
        quantity: 1,
        unitPrice: 45,
        total: 45,
      ),
      OrderItemModel(
        orderId: 7,
        menuItemId: 2,
        itemName: 'لاتيه',
        quantity: 1,
        unitPrice: 80,
        total: 80,
      ),
    ],
  );
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}
