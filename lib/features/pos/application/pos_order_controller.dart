import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/menu_item_model.dart';
import '../domain/pos_cart_item.dart';
import '../domain/pos_order_state.dart';

final posOrderControllerProvider =
    NotifierProvider<PosOrderController, PosOrderState>(PosOrderController.new);

class PosOrderController extends Notifier<PosOrderState> {
  @override
  PosOrderState build() => const PosOrderState();

  void configureVat({required bool enabled, required double percent}) {
    state = state.copyWith(vatEnabled: enabled, vatPercent: percent);
  }

  void addItem(MenuItemModel item) {
    final itemId = item.id ?? 0;
    if (itemId <= 0) return;
    final items = [...state.items];
    final index = items.indexWhere((cartItem) => cartItem.menuItemId == itemId);

    if (index == -1) {
      items.add(PosCartItem.fromMenuItem(item));
    } else {
      final existing = items[index];
      items[index] = existing.copyWith(quantity: existing.quantity + 1);
    }

    state = state.copyWith(items: items);
  }

  void increaseQuantity(int menuItemId) {
    if (menuItemId <= 0) return;
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.menuItemId == menuItemId)
            item.copyWith(quantity: item.quantity + 1)
          else
            item,
      ],
    );
  }

  void decreaseQuantity(int menuItemId) {
    if (menuItemId <= 0) return;
    final items = <PosCartItem>[];
    for (final item in state.items) {
      if (item.menuItemId != menuItemId) {
        items.add(item);
        continue;
      }

      final nextQuantity = item.quantity - 1;
      if (nextQuantity > 0) {
        items.add(item.copyWith(quantity: nextQuantity));
      }
    }

    state = state.copyWith(items: items);
  }

  void clearCart() {
    state = state.copyWith(items: []);
  }

  void resetForNextOrder() {
    state = PosOrderState(
      vatEnabled: state.vatEnabled,
      vatPercent: state.vatPercent,
    );
  }

  void setDiscountType(DiscountType discountType) {
    state = state.copyWith(discountType: discountType);
    setDiscountValue(state.discountValue);
  }

  void setDiscountValue(double value) {
    final safeValue = value.isFinite && value > 0 ? value : 0.0;
    final cappedValue = switch (state.discountType) {
      DiscountType.percent => safeValue > 100 ? 100.0 : safeValue,
      DiscountType.fixed =>
        safeValue > state.subtotal ? state.subtotal : safeValue,
    };

    state = state.copyWith(discountValue: cappedValue);
  }
}
