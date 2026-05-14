import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/repositories/order_repository.dart';
import '../../pos/presentation/widgets/invoice_preview_dialog.dart';
import '../application/orders_history_providers.dart';

class OrdersHistoryScreen extends ConsumerStatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  ConsumerState<OrdersHistoryScreen> createState() =>
      _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends ConsumerState<OrdersHistoryScreen> {
  final _searchController = TextEditingController();
  bool _isDetailsDialogOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersHistoryProvider);
    final filter = ref.watch(ordersHistoryFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الطلبات'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.welcome),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: 'رجوع',
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 32 : 16,
                vertical: 18,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FiltersPanel(
                        filter: filter,
                        controller: _searchController,
                        onFilterChanged: (value) => ref
                            .read(ordersHistoryFilterProvider.notifier)
                            .setDateFilter(value),
                        onSearchChanged: (value) => ref
                            .read(ordersHistoryFilterProvider.notifier)
                            .setSearch(value),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ordersAsync.when(
                          data: (orders) => _OrdersList(
                            orders: orders,
                            isWide: isWide,
                            onTap: _openOrderDetails,
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) => _MessageState(
                            icon: Icons.error_outline_rounded,
                            title: 'تعذر تحميل الطلبات',
                            subtitle: 'حاول مرة أخرى بعد لحظات',
                            action: OutlinedButton.icon(
                              onPressed: () =>
                                  ref.invalidate(ordersHistoryProvider),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openOrderDetails(OrderModel order) async {
    if (_isDetailsDialogOpen || order.id == null || order.id! <= 0) return;
    FocusScope.of(context).unfocus();

    _isDetailsDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => _OrderDetailsDialog(orderId: order.id!),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح تفاصيل الطلب')));
    } finally {
      _isDetailsDialogOpen = false;
    }
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.filter,
    required this.controller,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  final OrdersHistoryFilter filter;
  final TextEditingController controller;
  final ValueChanged<OrdersDateFilter> onFilterChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentBrown.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final option in OrdersDateFilter.values)
            ChoiceChip(
              label: Text(option.label),
              selected: filter.dateFilter == option,
              onSelected: (_) => onFilterChanged(option),
            ),
          SizedBox(
            width: 340,
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                labelText: 'بحث برقم الفاتورة أو العميل أو التليفون',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.background.withValues(alpha: 0.55),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.isWide,
    required this.onTap,
  });

  final List<OrderModel> orders;
  final bool isWide;
  final ValueChanged<OrderModel> onTap;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const _MessageState(
        icon: Icons.receipt_long_rounded,
        title: 'لا توجد طلبات',
        subtitle: 'ستظهر الطلبات المحفوظة هنا بعد تأكيدها من شاشة البيع',
      );
    }

    return ListView.separated(
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _OrderCard(order: orders[index], isWide: isWide, onTap: onTap);
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.isWide,
    required this.onTap,
  });

  final OrderModel order;
  final bool isWide;
  final ValueChanged<OrderModel> onTap;

  @override
  Widget build(BuildContext context) {
    final customerName = order.customerName?.trim().isNotEmpty == true
        ? order.customerName!
        : 'عميل عادي';

    return InkWell(
      onTap: () => onTap(order),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.accentBrown.withValues(alpha: 0.35),
          ),
        ),
        child: isWide
            ? Row(
                children: [
                  _InvoiceBadge(orderNumber: order.orderNumber),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _OrderMainInfo(
                      customerName: customerName,
                      order: order,
                    ),
                  ),
                  Expanded(child: Text(order.paymentMethod)),
                  Expanded(
                    child: Text(AppFormatters.dateTime(order.createdAt)),
                  ),
                  _StatusBadge(status: order.status),
                  const SizedBox(width: 16),
                  Text(
                    AppFormatters.currency(order.total),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primaryGold,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _InvoiceBadge(orderNumber: order.orderNumber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _OrderMainInfo(
                          customerName: customerName,
                          order: order,
                        ),
                      ),
                      _StatusBadge(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text(order.paymentMethod)),
                      Text(
                        AppFormatters.currency(order.total),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: AppColors.primaryGold),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _OrderMainInfo extends StatelessWidget {
  const _OrderMainInfo({required this.customerName, required this.order});

  final String customerName;
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final table = order.tableNumber?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(customerName, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          [
            if (table != null && table.isNotEmpty) 'ترابيزة $table',
            AppFormatters.dateTime(order.createdAt),
          ].join('  |  '),
          style: AppTextStyles.muted,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _InvoiceBadge extends StatelessWidget {
  const _InvoiceBadge({required this.orderNumber});

  final int orderNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.primaryGold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_rounded, color: AppColors.primaryGold),
          Text('#$orderNumber', style: AppTextStyles.muted),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = status == 'completed' ? 'مكتمل' : status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.body.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OrderDetailsDialog extends ConsumerStatefulWidget {
  const _OrderDetailsDialog({required this.orderId});

  final int orderId;

  @override
  ConsumerState<_OrderDetailsDialog> createState() =>
      _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends ConsumerState<_OrderDetailsDialog> {
  bool _isOpeningInvoice = false;

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(orderDetailsProvider(widget.orderId));
    final size = MediaQuery.sizeOf(context);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('تفاصيل الطلب'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.9 > 620 ? 620 : size.width * 0.9,
          maxHeight: size.height * 0.65,
        ),
        child: detailsAsync.when(
          data: (details) {
            if (details == null) {
              return const Text('تعذر العثور على الطلب');
            }
            return _OrderDetailsContent(details: details);
          },
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => const Text('تعذر تحميل تفاصيل الطلب'),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
        FilledButton.icon(
          onPressed: _isOpeningInvoice ? null : _openInvoice,
          icon: _isOpeningInvoice
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.receipt_long_rounded),
          label: Text(_isOpeningInvoice ? 'جاري الفتح' : 'فتح الفاتورة'),
        ),
      ],
    );
  }

  Future<void> _openInvoice() async {
    if (_isOpeningInvoice) return;
    setState(() => _isOpeningInvoice = true);
    try {
      final invoice = await ref.read(
        reopenedInvoiceProvider(widget.orderId).future,
      );
      if (!mounted) return;

      if (invoice == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح الفاتورة')));
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => InvoicePreviewDialog(invoice: invoice),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح الفاتورة')));
    } finally {
      if (mounted) {
        setState(() => _isOpeningInvoice = false);
      }
    }
  }
}

class _OrderDetailsContent extends StatelessWidget {
  const _OrderDetailsContent({required this.details});

  final OrderWithItems details;

  @override
  Widget build(BuildContext context) {
    final order = details.order;
    final customerName = order.customerName?.trim().isNotEmpty == true
        ? order.customerName!
        : 'عميل عادي';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _DetailLine(
            label: 'رقم الفاتورة',
            value: order.orderNumber.toString(),
          ),
          _DetailLine(
            label: 'التاريخ',
            value: AppFormatters.dateTime(order.createdAt),
          ),
          _DetailLine(label: 'العميل', value: customerName),
          if (order.customerPhone?.isNotEmpty == true)
            _DetailLine(label: 'رقم التليفون', value: order.customerPhone!),
          if (order.tableNumber?.isNotEmpty == true)
            _DetailLine(label: 'الترابيزة', value: order.tableNumber!),
          _DetailLine(label: 'طريقة الدفع', value: order.paymentMethod),
          const Divider(height: 26),
          ...details.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(child: Text('${item.itemName} × ${item.quantity}')),
                  Text(AppFormatters.currency(item.total)),
                ],
              ),
            ),
          ),
          const Divider(height: 26),
          _DetailLine(
            label: 'الإجمالي الفرعي',
            value: AppFormatters.currency(order.subtotal),
          ),
          _DetailLine(
            label: 'الخصم',
            value: AppFormatters.currency(order.discountAmount),
          ),
          _DetailLine(
            label: 'الضريبة',
            value: AppFormatters.currency(order.taxAmount),
          ),
          _DetailLine(
            label: 'الإجمالي النهائي',
            value: AppFormatters.currency(order.total),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.muted)),
          Text(
            value,
            style: emphasized
                ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.primaryGold,
                  )
                : Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
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
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
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
      ),
    );
  }
}
