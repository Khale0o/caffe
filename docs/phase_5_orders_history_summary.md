# Phase 5 Orders History and Invoice Reopen Summary

## Phase Name

Orders History and Invoice Reopen.

## What Was Implemented

- Replaced the `/orders` placeholder with a real orders history screen.
- Added recent orders list sorted newest first.
- Displayed invoice number, customer name, total, payment method, date/time, table number, and status badge.
- Added live date filters:
  - اليوم
  - أمس
  - هذا الشهر
  - الكل
- Added live search by:
  - invoice number
  - customer name
  - customer phone
- Added order details dialog loaded lazily from SQLite.
- Added invoice reopening from saved order data.
- Reused the Phase 4 invoice preview dialog for reopened invoices.
- Kept order items out of list queries for better performance.
- Added repository tests for filtering, searching, details loading, and invoice reopening.

## Files Created

- `lib/features/orders/application/orders_history_providers.dart`
- `lib/features/orders/presentation/orders_history_screen.dart`
- `docs/phase_5_orders_history_summary.md`

## Files Modified

- `lib/core/router/app_router.dart`
- `lib/features/pos/application/pos_checkout_service.dart`
- `lib/shared/repositories/order_repository.dart`
- `test/database_seed_test.dart`

## Repository Methods Added

- `OrderRepository.getOrders({DateTime? start, DateTime? end, String? search, int? customerId, int limit = 100})`
- `OrderRepository.searchOrders(String search, {int limit = 100})`
- `OrderRepository.getOrdersByDateRange({required DateTime start, required DateTime end, int limit = 100})`
- `OrderRepository.getOrdersByCustomer(int customerId, {int limit = 100})`
- `OrderRepository.getOrderWithItems(int orderId)`

Supporting model:

- `OrderWithItems`

## Orders Filtering Behavior

- Default filter is `اليوم`.
- `اليوم` loads orders from today 00:00 until tomorrow 00:00.
- `أمس` loads orders from yesterday 00:00 until today 00:00.
- `هذا الشهر` loads orders from the first day of the current month until the first day of the next month.
- `الكل` removes the date range filter.
- Search text is combined with the active date filter.
- Numeric search matches invoice number and also customer name/phone.
- Text search matches customer name or customer phone.
- Results are ordered by `created_at DESC, id DESC`.

## Invoice Reopening Flow

1. User opens `سجل الطلبات`.
2. User taps an order card.
3. The app lazily loads the order and its items from SQLite.
4. The details dialog shows invoice-style order information.
5. User taps `فتح الفاتورة`.
6. The app loads persisted order, persisted items, and current cafe settings.
7. The existing `InvoicePreviewDialog` opens with the saved invoice data.
8. This works after app restart because all invoice data comes from SQLite.

## State Management Summary

- `ordersHistoryFilterProvider` owns selected date filter and search text.
- `ordersHistoryProvider` queries orders based on the active filter state.
- `orderDetailsProvider` loads a single order with items only when details are opened.
- `reopenedInvoiceProvider` loads a persisted invoice payload for the invoice preview.
- `PosCheckoutService.loadInvoice` centralizes invoice reconstruction from saved order data.

## Manual Testing Checklist

- Save several orders from the POS screen.
- Open `سجل الطلبات` from the welcome screen.
- Confirm newest orders appear first.
- Confirm each card shows invoice number, customer, total, payment, date/time, table when available, and status.
- Switch filters between today, yesterday, this month, and all.
- Search by invoice number.
- Search by customer name.
- Search by customer phone.
- Tap an order and confirm details load.
- Confirm item quantities and totals appear correctly.
- Tap `فتح الفاتورة`.
- Confirm the invoice preview opens with persisted order data.
- Restart the app and reopen an old invoice from history.

## Verification Completed

- `flutter analyze` completed with no issues.
- `flutter test` completed successfully.
- `flutter build windows` completed successfully and produced `build\windows\x64\runner\Release\caffe.exe`.
- Order history queries were tested:
  - date range filtering
  - invoice number search
  - customer name search
  - customer phone search
  - customer-specific query
  - order details loading
  - invoice reopening payload from persisted data

## Known Limitations

- PDF printing is not implemented yet.
- Thermal printer support is not implemented yet.
- Admin menu management is not implemented yet.
- Reports screen is not implemented yet.
- Order cancellation, refunds, and status changes are not implemented yet.
- Search currently targets invoice number, customer name, and customer phone only.

## Next Recommended Phase

Phase 6 should implement PDF invoice generation and print/export preparation: generate a receipt PDF from saved invoice data, preview/export it locally, and keep thermal printer integration as a later dedicated phase.
