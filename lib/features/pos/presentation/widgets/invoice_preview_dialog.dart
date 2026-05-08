import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../invoices/application/invoice_pdf_service.dart';
import '../../application/pos_checkout_service.dart';

class InvoicePreviewDialog extends ConsumerStatefulWidget {
  const InvoicePreviewDialog({super.key, required this.invoice});

  final SavedOrderInvoice invoice;

  @override
  ConsumerState<InvoicePreviewDialog> createState() =>
      _InvoicePreviewDialogState();
}

class _InvoicePreviewDialogState extends ConsumerState<InvoicePreviewDialog> {
  bool _isExporting = false;
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.invoice.order;
    final size = MediaQuery.sizeOf(context);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('معاينة الفاتورة'),
      scrollable: false,
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.9 > 420 ? 420 : size.width * 0.9,
          maxHeight: size.height * 0.68,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.text,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: AppColors.background,
                      fontFamily: AppTextStyles.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.invoice.cafeName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (widget.invoice.cafePhone.isNotEmpty)
                          Text(
                            widget.invoice.cafePhone,
                            textAlign: TextAlign.center,
                          ),
                        if (widget.invoice.cafeAddress.isNotEmpty)
                          Text(
                            widget.invoice.cafeAddress,
                            textAlign: TextAlign.center,
                          ),
                        const _DashedDivider(),
                        _ReceiptLine(
                          label: 'رقم الفاتورة',
                          value: order.orderNumber.toString(),
                        ),
                        _ReceiptLine(
                          label: 'التاريخ',
                          value: AppFormatters.dateTime(order.createdAt),
                        ),
                        _ReceiptLine(
                          label: 'العميل',
                          value: order.customerName ?? 'عميل عادي',
                        ),
                        if (order.tableNumber?.isNotEmpty == true)
                          _ReceiptLine(
                            label: 'الترابيزة',
                            value: order.tableNumber!,
                          ),
                        _ReceiptLine(
                          label: 'الدفع',
                          value: order.paymentMethod,
                        ),
                        const _DashedDivider(),
                        ...widget.invoice.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.itemName} × ${item.quantity}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    AppFormatters.currency(item.total),
                                    textAlign: TextAlign.end,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const _DashedDivider(),
                        _ReceiptLine(
                          label: 'الإجمالي الفرعي',
                          value: AppFormatters.currency(order.subtotal),
                        ),
                        _ReceiptLine(
                          label: 'الخصم',
                          value: AppFormatters.currency(order.discountAmount),
                        ),
                        _ReceiptLine(
                          label: 'الضريبة',
                          value: AppFormatters.currency(order.taxAmount),
                        ),
                        const SizedBox(height: 8),
                        _ReceiptLine(
                          label: 'الإجمالي النهائي',
                          value: AppFormatters.currency(order.total),
                          emphasized: true,
                        ),
                        if (widget.invoice.footerMessage.isNotEmpty) ...[
                          const _DashedDivider(),
                          Text(
                            widget.invoice.footerMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: _showSharePlaceholder,
                  child: const Text('مشاركة لاحقاً'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _isExporting ? null : _exportPdf,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt_rounded),
                  label: const Text('حفظ PDF'),
                ),
                FilledButton.icon(
                  onPressed: _isPrinting ? null : _printPdf,
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_rounded),
                  label: const Text('طباعة PDF'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final path = await ref
          .read(invoicePdfServiceProvider)
          .exportInvoicePdf(widget.invoice);
      if (!mounted) return;
      _showMessage('تم حفظ ملف PDF في: $path');
    } catch (_) {
      if (!mounted) return;
      _showMessage('تعذر حفظ ملف PDF', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _printPdf() async {
    setState(() => _isPrinting = true);
    try {
      await ref.read(invoicePdfServiceProvider).printInvoicePdf(widget.invoice);
    } catch (_) {
      if (!mounted) return;
      _showMessage('تعذر إرسال ملف PDF للطباعة', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  void _showSharePlaceholder() {
    _showMessage('المشاركة سيتم تنفيذها في مرحلة لاحقة');
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: emphasized ? 18 : 14,
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Text(
        '--------------------------------',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted),
      ),
    );
  }
}
