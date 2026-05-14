# Phase 8: Reports and Sales Analytics

## What was implemented

- Replaced the reports placeholder route with a production reports dashboard.
- Added local SQLite analytics for sales, orders, VAT, discounts, customers, payment methods, item rankings, and daily trends.
- Added live report filters for:
  - اليوم
  - أمس
  - هذا الأسبوع
  - هذا الشهر
  - كل الوقت
  - فترة مخصصة
- Added responsive dark-theme charts without adding a new dependency.
- Added Top 5 / Top 10 item ranking toggle.

## Files created

- `lib/features/reports/domain/reports_models.dart`
- `lib/features/reports/application/reports_providers.dart`
- `lib/features/reports/presentation/reports_screen.dart`
- `lib/shared/repositories/reports_repository.dart`
- `test/reports_analytics_test.dart`
- `docs/phase_8_reports_analytics_summary.md`

## Files modified

- `lib/core/router/app_router.dart`
- `test/stabilization_layout_test.dart`

## Analytics calculations

- Total sales: `SUM(orders.total)`
- Orders count: `COUNT(orders.id)`
- Average order value: `AVG(orders.total)`
- Total VAT collected: `SUM(orders.tax_amount)`
- Total discounts given: `SUM(orders.discount_amount)`
- Total customers: `COUNT(customers.id)`
- Payment revenue: grouped `SUM(orders.total)` by payment method
- Payment usage: grouped `COUNT(orders.id)` by payment method
- Payment percentage: method order count divided by total filtered orders
- Best-selling items: grouped `SUM(order_items.quantity)` by item name
- Top revenue items: grouped `SUM(order_items.total)` by item name
- Least sold items: grouped quantity ascending
- Daily sales trend: grouped `SUM(orders.total)` by `created_at` day

## Repository methods added

- `ReportsRepository.getSalesSummary`
- `ReportsRepository.getCustomerCount`
- `ReportsRepository.getTopPaymentMethod`
- `ReportsRepository.getPaymentAnalytics`
- `ReportsRepository.getItemAnalytics`
- `ReportsRepository.getDailySalesTrend`

The widgets do not contain raw SQL. All analytics queries live in `ReportsRepository`.

## Filter behavior

- Changing a preset updates Riverpod state and refreshes analytics automatically.
- Custom range uses `showDateRangePicker`.
- Date ranges are normalized to full days.
- The selected filter drives trend, payment, and item analytics.
- Dashboard cards for today and this month always show fixed current-period totals.

## Charts added

- Daily sales trend line/area chart.
- Payment method donut chart with usage, revenue, and percentage rows.
- Top item bar charts for quantity, revenue, and least sold items.

The charts are built with Flutter `CustomPainter`, `LinearProgressIndicator`, and layout primitives to avoid new package risk in this phase.

## Performance considerations

- Uses SQLite aggregate queries instead of loading all orders into memory.
- Filters are pushed into SQL with date range `WHERE` clauses.
- Item and payment summaries are grouped in SQLite.
- Item ranking queries use `LIMIT` for Top 5 / Top 10.
- The dashboard provider performs focused aggregate reads and can be invalidated by pull-to-refresh.

## Manual testing checklist

- Open reports from the welcome screen.
- Verify dashboard cards after saving several orders.
- Switch between اليوم, أمس, هذا الأسبوع, هذا الشهر, and كل الوقت.
- Pick a custom date range and confirm analytics refresh.
- Confirm empty state appears for ranges with no orders.
- Verify payment chart for كاش, فيزا, فودافون كاش, and إنستا باي.
- Toggle Top 5 / Top 10 and confirm item lists refresh.
- Resize Windows desktop from narrow to wide.
- Test reports on Android phone/tablet for scrolling and chart visibility.
- Confirm orders history and POS save behavior still work after reports reads.

## Known limitations

- PDF report export is not implemented in this phase.
- Excel export is not implemented in this phase.
- Inventory, stock, cost, and profit analytics are intentionally out of scope.
- Analytics are based only on locally persisted SQLite order data.
- Daily trend displays only days that have sales; zero-sales gap filling can be added later if needed.

## Next recommended phase

Add optional report export workflows, starting with PDF and Excel export using the repository analytics already added here.
