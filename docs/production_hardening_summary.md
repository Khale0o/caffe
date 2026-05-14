# Real Device QA and Production Hardening Summary

## Issues improved

- Added reentrancy guards around order review, order confirmation, invoice reopening, PDF export, PDF printing, customer lookup, customer creation, admin PIN verification, and admin menu/settings saves.
- Hardened invalid IDs for customer routing, cart item mutations, and order invoice/detail reopening.
- Added safer VAT parsing so malformed, negative, or non-finite settings fall back to a production-safe value.
- Preserved SQLite-only local storage and the existing Windows/Android architecture.

## UX improvements

- Disabled key action buttons while work is processing.
- Added progress indicators to save/open/export paths that can take noticeable time on real devices.
- Dismissed the keyboard before searches, saves, review dialogs, and long scrolling interactions.
- Improved numeric keyboard usage for table number, discount, VAT, admin PIN, and item price fields.
- Added next/done keyboard actions to high-use forms.

## Reliability improvements

- Prevented duplicate order saves from repeated confirm taps.
- Prevented overlapping PDF export and print operations from the invoice dialog.
- Prevented stacked order detail dialogs and repeated invoice reopen actions.
- Added defensive handling for invalid order IDs and invalid customer IDs.
- Converted SQLite checkout failures into user-facing checkout errors where possible.
- Ensured loading flags reset in finally blocks after success or failure.

## Performance optimizations

- Reduced avoidable async churn by blocking repeated actions while the first operation is still active.
- Kept orders history and admin lists on existing lazy/list rendering patterns without changing architecture.
- Avoided unnecessary schema or database migration changes.
- Kept invoice reopening defensive and short-circuited invalid IDs before repository reads.

## Mobile/tablet polish

- Added keyboard-aware padding and drag-to-dismiss keyboard behavior on mobile customer/admin flows.
- Improved mobile cart bottom sheet padding above the Android keyboard.
- Disabled the floating mobile cart action while checkout is saving.
- Kept dialogs constrained to available screen height and added guarded actions for short windows.

## Files modified

- `lib/core/router/app_router.dart`
- `lib/features/admin/presentation/admin_screen.dart`
- `lib/features/customer_entry/presentation/customer_entry_screen.dart`
- `lib/features/orders/application/orders_history_providers.dart`
- `lib/features/orders/presentation/orders_history_screen.dart`
- `lib/features/pos/application/pos_checkout_service.dart`
- `lib/features/pos/application/pos_order_controller.dart`
- `lib/features/pos/presentation/pos_screen.dart`
- `lib/features/pos/presentation/widgets/invoice_preview_dialog.dart`
- `lib/shared/repositories/order_repository.dart`
- `test/orders_history_providers_test.dart`
- `test/pos_order_controller_test.dart`

## Production safety improvements

- Order save remains transactional through `OrderRepository.createOrder`.
- Invalid customer IDs now fail the transaction instead of silently creating a dangling customer reference.
- PDF export/print cannot run concurrently from repeated taps.
- Invoice export continues to use a stable invoice file name per order number, avoiding accidental duplicate files from button spam.
- Dialog and navigation actions are guarded against rapid repeated taps.

## Remaining known issues

- Full real-device QA still needs to be executed on representative Android phones/tablets and the target Windows cashier hardware.
- PDF printer driver behavior can vary by Windows device and Android print service.
- The app remains local SQLite only; no cloud backup or multi-device sync is included in this phase.

## Manual testing checklist

- Save an order by tapping confirm repeatedly and verify only one order is created.
- Export and print the same invoice with repeated taps and verify buttons stay disabled while busy.
- Reopen invoices from order history repeatedly and verify dialogs do not stack.
- Test customer search/create on Android with the keyboard visible.
- Test POS mobile cart bottom sheet with table number and discount focused.
- Test admin category/item/settings dialogs on small Android screens.
- Resize Windows desktop from narrow to wide while on POS, admin, and orders history.
- Scroll long menu/admin/order lists with mouse wheel and touch.
- Test invalid or deleted customer/order paths where possible.
- Confirm loading states clear after simulated save/export failures.

## Recommended next phase

Run a structured real-device QA cycle on Android and Windows, capture device-specific issues, then prioritize only production blockers before starting reports, cloud sync, or any new business features.
