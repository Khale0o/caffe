import 'package:caffe/features/pos/application/pos_order_controller.dart';
import 'package:caffe/features/pos/domain/pos_order_state.dart';
import 'package:caffe/shared/models/menu_item_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MenuItemModel menuItem({
    required int id,
    required String name,
    required double price,
  }) {
    return MenuItemModel(
      id: id,
      categoryId: 1,
      name: name,
      price: price,
      createdAt: DateTime(2026),
    );
  }

  test('cart adds, increases, decreases, and removes items', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(posOrderControllerProvider.notifier);
    final espresso = menuItem(id: 1, name: 'إسبريسو', price: 45);

    controller.addItem(espresso);
    controller.addItem(espresso);
    expect(container.read(posOrderControllerProvider).itemCount, 2);
    expect(container.read(posOrderControllerProvider).items.single.quantity, 2);

    controller.decreaseQuantity(1);
    expect(container.read(posOrderControllerProvider).items.single.quantity, 1);

    controller.decreaseQuantity(1);
    expect(container.read(posOrderControllerProvider).items, isEmpty);
  });

  test('percentage discount is capped at 100 percent', () {
    final totals = PosOrderState.calculateTotals(
      subtotal: 200,
      discountValue: 150,
      discountType: DiscountType.percent,
      vatEnabled: true,
      vatPercent: 14,
    );

    expect(totals.discountAmount, 200);
    expect(totals.afterDiscount, 0);
    expect(totals.vatAmount, 0);
    expect(totals.grandTotal, 0);
  });

  test('fixed discount cannot exceed subtotal', () {
    final totals = PosOrderState.calculateTotals(
      subtotal: 120,
      discountValue: 200,
      discountType: DiscountType.fixed,
      vatEnabled: true,
      vatPercent: 14,
    );

    expect(totals.discountAmount, 120);
    expect(totals.grandTotal, 0);
  });

  test('VAT calculation follows setting and can be disabled', () {
    final enabledTotals = PosOrderState.calculateTotals(
      subtotal: 100,
      discountValue: 10,
      discountType: DiscountType.percent,
      vatEnabled: true,
      vatPercent: 14,
    );
    final disabledTotals = PosOrderState.calculateTotals(
      subtotal: 100,
      discountValue: 10,
      discountType: DiscountType.percent,
      vatEnabled: false,
      vatPercent: 14,
    );

    expect(enabledTotals.afterDiscount, 90);
    expect(enabledTotals.vatAmount, 12.6);
    expect(enabledTotals.grandTotal, 102.6);
    expect(disabledTotals.vatAmount, 0);
    expect(disabledTotals.grandTotal, 90);
  });

  test(
    'resetForNextOrder clears cart and discount while keeping VAT settings',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(posOrderControllerProvider.notifier);

      controller.configureVat(enabled: true, percent: 10);
      controller.addItem(menuItem(id: 2, name: 'لاتيه', price: 75));
      controller.setDiscountValue(15);
      controller.resetForNextOrder();

      final state = container.read(posOrderControllerProvider);
      expect(state.items, isEmpty);
      expect(state.discountValue, 0);
      expect(state.discountType, DiscountType.percent);
      expect(state.vatEnabled, isTrue);
      expect(state.vatPercent, 10);
    },
  );

  test('controller ignores invalid item ids and non-finite discounts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(posOrderControllerProvider.notifier);

    controller.addItem(menuItem(id: 0, name: 'Invalid', price: 50));
    controller.increaseQuantity(0);
    controller.decreaseQuantity(-1);
    controller.setDiscountValue(double.nan);

    final state = container.read(posOrderControllerProvider);
    expect(state.items, isEmpty);
    expect(state.discountValue, 0);
  });
}
