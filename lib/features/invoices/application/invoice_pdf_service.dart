import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/formatters.dart';
import '../../pos/application/pos_checkout_service.dart';

final invoicePdfServiceProvider = Provider<InvoicePdfService>((ref) {
  return const InvoicePdfService();
});

class InvoicePdfService {
  const InvoicePdfService();

  static const arabicFontAsset = 'assets/fonts/arial.ttf';
  static const receiptPageFormat = PdfPageFormat(
    80 * PdfPageFormat.mm,
    300 * PdfPageFormat.mm,
    marginAll: 0,
  );

  Future<Uint8List> generateInvoicePdf(SavedOrderInvoice invoice) async {
    final font = await loadArabicFont();
    final document = pw.Document();
    final order = invoice.order;

    document.addPage(
      pw.MultiPage(
        pageFormat: receiptPageFormat.copyWith(
          marginLeft: 14,
          marginRight: 14,
          marginTop: 18,
          marginBottom: 18,
        ),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              invoice.cafeName,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          if (invoice.cafePhone.isNotEmpty)
            _centerText(invoice.cafePhone, fontSize: 9),
          if (invoice.cafeAddress.isNotEmpty)
            _centerText(invoice.cafeAddress, fontSize: 9),
          _divider(),
          _line('رقم الفاتورة', order.orderNumber.toString()),
          _line('التاريخ', AppFormatters.dateTime(order.createdAt)),
          _line('العميل', order.customerName ?? 'عميل عادي'),
          if (order.customerPhone?.isNotEmpty == true)
            _line('رقم التليفون', order.customerPhone!),
          if (order.tableNumber?.isNotEmpty == true)
            _line('الترابيزة', order.tableNumber!),
          _line('طريقة الدفع', order.paymentMethod),
          _divider(),
          _itemsHeader(),
          pw.SizedBox(height: 6),
          ...invoice.items.map(
            (item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(flex: 4, child: pw.Text(item.itemName)),
                  pw.Expanded(
                    child: pw.Text(
                      item.quantity.toString(),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      AppFormatters.currency(item.unitPrice),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      AppFormatters.currency(item.total),
                      textAlign: pw.TextAlign.left,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _divider(),
          _line('الإجمالي الفرعي', AppFormatters.currency(order.subtotal)),
          _line('الخصم', AppFormatters.currency(order.discountAmount)),
          _line(
            'ضريبة القيمة المضافة',
            AppFormatters.currency(order.taxAmount),
          ),
          pw.SizedBox(height: 6),
          _line(
            'الإجمالي النهائي',
            AppFormatters.currency(order.total),
            fontSize: 13,
            bold: true,
          ),
          if (invoice.footerMessage.isNotEmpty) ...[
            _divider(),
            _centerText(invoice.footerMessage, fontSize: 10, bold: true),
          ],
        ],
      ),
    );

    return document.save();
  }

  Future<pw.Font> loadArabicFont() async {
    final fontData = await rootBundle.load(arabicFontAsset);
    return pw.Font.ttf(fontData);
  }

  Future<String> exportInvoicePdf(SavedOrderInvoice invoice) async {
    final bytes = await generateInvoicePdf(invoice);
    final directory = await getApplicationDocumentsDirectory();
    final fileName = invoiceFileName(invoice.order.orderNumber);
    final path = p.join(directory.path, fileName);
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<void> printInvoicePdf(SavedOrderInvoice invoice) async {
    final fileName = invoiceFileName(invoice.order.orderNumber);
    await Printing.layoutPdf(
      name: fileName,
      format: receiptPageFormat,
      onLayout: (_) => generateInvoicePdf(invoice),
    );
  }

  String invoiceFileName(int orderNumber) {
    return 'invoice_${orderNumber.toString().padLeft(4, '0')}.pdf';
  }

  pw.Widget _centerText(
    String value, {
    double fontSize = 10,
    bool bold = false,
  }) {
    return pw.Center(
      child: pw.Text(
        value,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _divider() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Divider(thickness: 0.6, color: PdfColors.grey600),
    );
  }

  pw.Widget _line(
    String label,
    String value, {
    double fontSize = 10,
    bool bold = false,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(value, style: style, textAlign: pw.TextAlign.left),
        ],
      ),
    );
  }

  pw.Widget _itemsHeader() {
    final style = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
    return pw.Row(
      children: [
        pw.Expanded(flex: 4, child: pw.Text('الصنف', style: style)),
        pw.Expanded(
          child: pw.Text(
            'الكمية',
            textAlign: pw.TextAlign.center,
            style: style,
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Text('السعر', textAlign: pw.TextAlign.center, style: style),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            'الإجمالي',
            textAlign: pw.TextAlign.left,
            style: style,
          ),
        ),
      ],
    );
  }
}
