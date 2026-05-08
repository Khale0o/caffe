import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/order_model.dart';
import '../../../shared/repositories/order_repository.dart';
import '../../pos/application/pos_checkout_service.dart';

enum OrdersDateFilter {
  today,
  yesterday,
  thisMonth,
  all;

  String get label => switch (this) {
    OrdersDateFilter.today => 'اليوم',
    OrdersDateFilter.yesterday => 'أمس',
    OrdersDateFilter.thisMonth => 'هذا الشهر',
    OrdersDateFilter.all => 'الكل',
  };
}

class OrdersHistoryFilter {
  const OrdersHistoryFilter({
    this.dateFilter = OrdersDateFilter.today,
    this.search = '',
  });

  final OrdersDateFilter dateFilter;
  final String search;

  OrdersHistoryFilter copyWith({OrdersDateFilter? dateFilter, String? search}) {
    return OrdersHistoryFilter(
      dateFilter: dateFilter ?? this.dateFilter,
      search: search ?? this.search,
    );
  }

  ({DateTime? start, DateTime? end}) get range {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (dateFilter) {
      OrdersDateFilter.today => (
        start: today,
        end: today.add(const Duration(days: 1)),
      ),
      OrdersDateFilter.yesterday => (
        start: today.subtract(const Duration(days: 1)),
        end: today,
      ),
      OrdersDateFilter.thisMonth => (
        start: DateTime(now.year, now.month),
        end: DateTime(now.year, now.month + 1),
      ),
      OrdersDateFilter.all => (start: null, end: null),
    };
  }
}

final ordersHistoryFilterProvider =
    NotifierProvider<OrdersHistoryFilterController, OrdersHistoryFilter>(
      OrdersHistoryFilterController.new,
    );

class OrdersHistoryFilterController extends Notifier<OrdersHistoryFilter> {
  @override
  OrdersHistoryFilter build() => const OrdersHistoryFilter();

  void setDateFilter(OrdersDateFilter filter) {
    state = state.copyWith(dateFilter: filter);
  }

  void setSearch(String search) {
    state = state.copyWith(search: search);
  }
}

final ordersHistoryProvider = FutureProvider<List<OrderModel>>((ref) {
  final filter = ref.watch(ordersHistoryFilterProvider);
  final range = filter.range;
  return ref
      .watch(orderRepositoryProvider)
      .getOrders(start: range.start, end: range.end, search: filter.search);
});

final orderDetailsProvider = FutureProvider.family<OrderWithItems?, int>((
  ref,
  orderId,
) {
  return ref.watch(orderRepositoryProvider).getOrderWithItems(orderId);
});

final reopenedInvoiceProvider = FutureProvider.family<SavedOrderInvoice?, int>((
  ref,
  orderId,
) async {
  return ref.watch(posCheckoutServiceProvider).loadInvoice(orderId);
});
