import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../shared/models/customer_model.dart';
import '../../../shared/models/order_item_model.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/repositories/order_repository.dart';
import '../../../shared/repositories/settings_repository.dart';
import '../domain/pos_order_state.dart';

final posCheckoutServiceProvider = Provider<PosCheckoutService>((ref) {
  return PosCheckoutService(
    orderRepository: ref.watch(orderRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});

class PosCheckoutService {
  const PosCheckoutService({
    required OrderRepository orderRepository,
    required SettingsRepository settingsRepository,
  }) : _orderRepository = orderRepository,
       _settingsRepository = settingsRepository;

  final OrderRepository _orderRepository;
  final SettingsRepository _settingsRepository;

  Future<SavedOrderInvoice> saveOrder({
    required CustomerModel? customer,
    required PosOrderState orderState,
    required String tableNumber,
    required String paymentMethod,
  }) async {
    if (orderState.items.isEmpty) {
      throw const PosCheckoutException('لا يمكن حفظ طلب بدون أصناف');
    }

    final totals = orderState.totals;
    if (totals.grandTotal < 0) {
      throw const PosCheckoutException('إجمالي الطلب غير صحيح');
    }

    try {
      final now = DateTime.now();
      final orderNumber = await _orderRepository.getNextOrderNumber();
      final trimmedTableNumber = tableNumber.trim();
      final order = OrderModel(
        orderNumber: orderNumber,
        customerId: customer?.id,
        customerName: customer?.name,
        customerPhone: customer?.phone,
        tableNumber: trimmedTableNumber.isEmpty ? null : trimmedTableNumber,
        paymentMethod: paymentMethod,
        subtotal: totals.subtotal,
        discountValue: orderState.discountValue,
        discountType: orderState.discountType.storageValue,
        discountAmount: totals.discountAmount,
        taxAmount: totals.vatAmount,
        total: totals.grandTotal,
        status: 'completed',
        createdAt: now,
      );
      final items = orderState.items.map((item) {
        return OrderItemModel(
          orderId: 0,
          menuItemId: item.menuItemId,
          itemName: item.name,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          total: item.total,
        );
      }).toList();

      final orderId = await _orderRepository.createOrder(order, items);
      final savedOrder = await _orderRepository.getOrderById(orderId);
      final savedItems = await _orderRepository.getOrderItems(orderId);
      final settings = await _settingsRepository.getAll();

      if (savedOrder == null || savedItems.isEmpty) {
        throw const PosCheckoutException('تم الحفظ ولكن تعذر تحميل الفاتورة');
      }

      return SavedOrderInvoice(
        order: savedOrder,
        items: savedItems,
        cafeName: _setting(settings, 'cafe_name', 'كافيه النيل'),
        cafePhone: _setting(settings, 'cafe_phone', ''),
        cafeAddress: _setting(settings, 'cafe_address', ''),
        footerMessage: _setting(settings, 'invoice_footer', ''),
      );
    } on PosCheckoutException {
      rethrow;
    } on DatabaseException {
      throw const PosCheckoutException('تعذر حفظ الطلب في قاعدة البيانات');
    } on StateError {
      throw const PosCheckoutException('تعذر حفظ الطلب بسبب بيانات غير صالحة');
    }
  }

  Future<SavedOrderInvoice?> loadInvoice(int orderId) async {
    if (orderId <= 0) return null;

    try {
      final orderWithItems = await _orderRepository.getOrderWithItems(orderId);
      if (orderWithItems == null || orderWithItems.items.isEmpty) return null;

      final settings = await _settingsRepository.getAll();
      return SavedOrderInvoice(
        order: orderWithItems.order,
        items: orderWithItems.items,
        cafeName: _setting(settings, 'cafe_name', 'كافيه النيل'),
        cafePhone: _setting(settings, 'cafe_phone', ''),
        cafeAddress: _setting(settings, 'cafe_address', ''),
        footerMessage: _setting(settings, 'invoice_footer', ''),
      );
    } on DatabaseException {
      return null;
    }
  }

  String _setting(Map<String, String?> settings, String key, String fallback) {
    final value = settings[key];
    return value == null || value.isEmpty ? fallback : value;
  }
}

class SavedOrderInvoice {
  const SavedOrderInvoice({
    required this.order,
    required this.items,
    required this.cafeName,
    required this.cafePhone,
    required this.cafeAddress,
    required this.footerMessage,
  });

  final OrderModel order;
  final List<OrderItemModel> items;
  final String cafeName;
  final String cafePhone;
  final String cafeAddress;
  final String footerMessage;
}

class PosCheckoutException implements Exception {
  const PosCheckoutException(this.message);

  final String message;
}
