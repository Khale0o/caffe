# Phase 4 Order Persistence and Invoice Foundation Summary

## Phase Name

Order Persistence and Invoice Foundation.

## What Was Implemented

- Replaced the Phase 3 `تأكيد لاحقاً` behavior with real local order saving.
- Added transactional order persistence into SQLite.
- Saved order item snapshots into SQLite.
- Added local sequential order number generation.
- Updated customer `order_count` when an order is saved for a registered customer.
- Added checkout service layer for converting POS state into persisted order records.
- Added post-save POS reset behavior.
- Added receipt-style invoice preview dialog.
- Loaded invoice cafe name, phone, address, and footer from local settings.
- Kept PDF generation and printing out of this phase.
- Kept reports/admin functionality out of this phase.

## Files Created

- `lib/features/pos/application/pos_checkout_service.dart`
- `lib/features/pos/presentation/widgets/invoice_preview_dialog.dart`
- `docs/phase_4_order_persistence_summary.md`

## Files Modified

- `lib/features/pos/application/pos_order_controller.dart`
- `lib/features/pos/domain/pos_order_state.dart`
- `lib/features/pos/presentation/pos_screen.dart`
- `lib/shared/repositories/order_repository.dart`
- `test/database_seed_test.dart`
- `test/pos_order_controller_test.dart`

## Repository Methods Added

- `OrderRepository.getNextOrderNumber()`
- `OrderRepository.getOrderById(int id)`
- `OrderRepository.getOrderItems(int orderId)`
- `OrderRepository.getRecentOrders({int limit = 50})`
- `OrderRepository.getTodayOrdersCount()`
- `OrderRepository.getTodaySales()`

Existing compatibility wrappers remain available:

- `nextOrderNumber()`
- `findById(int id)`
- `orderItems(int orderId)`
- `recentOrders({int limit = 50})`
- `todayOrdersCount()`
- `todaySalesTotal()`

## Order Save Flow

1. Cashier adds items in the POS screen.
2. Cashier taps `مراجعة الطلب`.
3. Review dialog opens with customer, table, payment, items, and totals.
4. Cashier taps `تأكيد الطلب`.
5. The app validates that the cart is not empty.
6. The app generates the next local order number from SQLite.
7. The app saves the order row into `orders`.
8. The app saves each cart item into `order_items`.
9. If the order has a registered customer, the customer `order_count` is incremented.
10. The POS cart and order options reset.
11. A success message is shown.
12. The invoice preview dialog opens.

## Invoice Preview Flow

- The invoice preview opens immediately after a successful save.
- It shows:
  - Cafe name
  - Cafe phone
  - Cafe address
  - Invoice number
  - Date/time
  - Customer name or `عميل عادي`
  - Table number when available
  - Payment method
  - Item names, quantities, and totals
  - Subtotal
  - Discount
  - VAT
  - Grand total
  - Footer message
- Buttons:
  - `إغلاق`
  - `إعادة فتح لاحقاً`
- Both buttons only close the preview in this phase.

## Database Persistence Behavior

- Order numbers start from 1 when no orders exist.
- Next order number is calculated as `MAX(order_number) + 1`.
- Order numbers survive app restarts because they are based on persisted SQLite rows.
- Orders persist customer snapshot fields:
  - customer ID
  - customer name
  - customer phone
- Orders persist table number, payment method, subtotal, discount value/type/amount, tax amount, total, status, and creation time.
- Order items persist menu item ID, item name snapshot, quantity, unit price, and total.
- Order creation and customer count update run in one SQLite transaction.

## State Management Updates

- `PosCheckoutService` owns checkout persistence orchestration.
- `posCheckoutServiceProvider` exposes the service through Riverpod.
- `PosOrderController.resetForNextOrder()` clears cart and discount while preserving loaded VAT settings.
- POS screen keeps temporary UI inputs such as table number and payment method, then resets them after save.
- Calculation logic remains in `PosOrderState` and is still testable independently.

## Manual Testing Checklist

- Open the app on Windows.
- Start a new order from the welcome screen.
- Continue as a walk-in customer or select/create a registered customer.
- Add one or more menu items to the cart.
- Adjust quantities with plus/minus buttons.
- Set table number.
- Select each payment method.
- Enter percentage and fixed discounts.
- Tap `مراجعة الطلب`.
- Confirm the review dialog displays correct totals.
- Tap `تأكيد الطلب`.
- Confirm a success message appears.
- Confirm the invoice preview opens.
- Confirm invoice data matches the order.
- Close the invoice preview.
- Confirm cart is empty and payment resets to `كاش`.
- For a registered customer, create another order and confirm order count increments.
- Restart the app and save another order to confirm order numbering continues from persisted data.

## Verification Completed

- `flutter analyze` completed with no issues.
- `flutter test` completed successfully.
- `flutter build windows` completed successfully and produced `build\windows\x64\runner\Release\caffe.exe`.
- Order persistence was tested:
  - next order number starts at 1
  - saved order can be loaded by ID
  - saved order items can be loaded
  - customer `order_count` increments
  - next order number advances to 2
  - today order count and today sales update
- Cart reset after save was tested at controller level.

## Known Limitations

- PDF invoice generation is not implemented yet.
- Thermal printer support is not implemented yet.
- Reports screen is not implemented yet.
- Admin menu management is not implemented yet.
- Invoice preview can be closed only; reopening previous invoices from history is not implemented yet.
- Order editing, cancelling, and refunds are not implemented yet.

## Next Recommended Phase

Phase 5 should implement order history and invoice reopening: list recent orders, view saved order details, reopen invoice previews, filter by date/customer/payment method, and prepare the UI foundation for future PDF/printing support.
