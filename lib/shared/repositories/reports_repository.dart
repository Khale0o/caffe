import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../../features/reports/domain/reports_models.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(AppDatabase.instance);
});

enum ItemAnalyticsSort { quantityDesc, revenueDesc, quantityAsc }

class ReportsRepository {
  const ReportsRepository(this._appDatabase);

  static const paymentMethods = ['كاش', 'فيزا', 'فودافون كاش', 'إنستا باي'];

  final AppDatabase _appDatabase;

  Future<Database> get _db => _appDatabase.database;

  Future<SalesSummary> getSalesSummary({DateTime? start, DateTime? end}) async {
    final db = await _db;
    final query = _dateWhere(start: start, end: end, tableAlias: 'o');
    final rows = await db.rawQuery('''
      SELECT
        COUNT(o.id) AS order_count,
        COALESCE(SUM(o.total), 0) AS total_sales,
        COALESCE(AVG(o.total), 0) AS average_order_value,
        COALESCE(SUM(o.tax_amount), 0) AS total_vat,
        COALESCE(SUM(o.discount_amount), 0) AS total_discount
      FROM ${DatabaseTables.orders} o
      ${query.sql}
      ''', query.args);
    final row = rows.first;
    return SalesSummary(
      totalSales: _double(row['total_sales']),
      orderCount: _int(row['order_count']),
      averageOrderValue: _double(row['average_order_value']),
      totalVat: _double(row['total_vat']),
      totalDiscount: _double(row['total_discount']),
    );
  }

  Future<int> getCustomerCount() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS customer_count FROM ${DatabaseTables.customers}',
    );
    return _int(rows.first['customer_count']);
  }

  Future<String> getTopPaymentMethod({DateTime? start, DateTime? end}) async {
    final db = await _db;
    final query = _dateWhere(start: start, end: end, tableAlias: 'o');
    final rows = await db.rawQuery('''
      SELECT o.payment_method, COUNT(o.id) AS order_count
      FROM ${DatabaseTables.orders} o
      ${query.sql}
      GROUP BY o.payment_method
      ORDER BY order_count DESC, SUM(o.total) DESC
      LIMIT 1
      ''', query.args);
    if (rows.isEmpty) return '-';
    return (rows.first['payment_method'] as String?) ?? '-';
  }

  Future<List<PaymentAnalytics>> getPaymentAnalytics({
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await _db;
    final query = _dateWhere(start: start, end: end, tableAlias: 'o');
    final rows = await db.rawQuery('''
      SELECT
        o.payment_method,
        COUNT(o.id) AS order_count,
        COALESCE(SUM(o.total), 0) AS revenue
      FROM ${DatabaseTables.orders} o
      ${query.sql}
      GROUP BY o.payment_method
      ''', query.args);

    final byMethod = {
      for (final row in rows)
        (row['payment_method'] as String? ?? '-'): (
          count: _int(row['order_count']),
          revenue: _double(row['revenue']),
        ),
    };
    final totalOrders = byMethod.values.fold<int>(
      0,
      (sum, value) => sum + value.count,
    );

    return [
      for (final method in paymentMethods)
        PaymentAnalytics(
          method: method,
          orderCount: byMethod[method]?.count ?? 0,
          revenue: byMethod[method]?.revenue ?? 0,
          percentage: totalOrders == 0
              ? 0
              : ((byMethod[method]?.count ?? 0) / totalOrders) * 100,
        ),
    ];
  }

  Future<List<ItemAnalytics>> getItemAnalytics({
    DateTime? start,
    DateTime? end,
    required ItemAnalyticsSort sort,
    int limit = 5,
  }) async {
    final db = await _db;
    final query = _dateWhere(start: start, end: end, tableAlias: 'o');
    final orderBy = switch (sort) {
      ItemAnalyticsSort.quantityDesc => 'quantity DESC, revenue DESC',
      ItemAnalyticsSort.revenueDesc => 'revenue DESC, quantity DESC',
      ItemAnalyticsSort.quantityAsc => 'quantity ASC, revenue ASC',
    };
    final rows = await db.rawQuery(
      '''
      SELECT
        oi.item_name,
        COALESCE(SUM(oi.quantity), 0) AS quantity,
        COALESCE(SUM(oi.total), 0) AS revenue
      FROM ${DatabaseTables.orderItems} oi
      INNER JOIN ${DatabaseTables.orders} o ON o.id = oi.order_id
      ${query.sql}
      GROUP BY oi.item_name
      ORDER BY $orderBy
      LIMIT ?
      ''',
      [...query.args, limit],
    );

    return rows
        .map(
          (row) => ItemAnalytics(
            itemName: row['item_name'] as String? ?? '-',
            quantity: _int(row['quantity']),
            revenue: _double(row['revenue']),
          ),
        )
        .toList();
  }

  Future<List<DailySalesPoint>> getDailySalesTrend({
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await _db;
    final query = _dateWhere(start: start, end: end, tableAlias: 'o');
    final rows = await db.rawQuery('''
      SELECT
        substr(o.created_at, 1, 10) AS sales_day,
        COALESCE(SUM(o.total), 0) AS total_sales,
        COUNT(o.id) AS order_count
      FROM ${DatabaseTables.orders} o
      ${query.sql}
      GROUP BY sales_day
      ORDER BY sales_day ASC
      ''', query.args);

    return rows
        .map(
          (row) => DailySalesPoint(
            date: DateTime.parse(row['sales_day'] as String),
            totalSales: _double(row['total_sales']),
            orderCount: _int(row['order_count']),
          ),
        )
        .toList();
  }

  _SqlFilter _dateWhere({
    required DateTime? start,
    required DateTime? end,
    required String tableAlias,
  }) {
    final filters = <String>[];
    final args = <Object?>[];

    if (start != null) {
      filters.add('$tableAlias.created_at >= ?');
      args.add(start.toIso8601String());
    }
    if (end != null) {
      filters.add('$tableAlias.created_at < ?');
      args.add(end.toIso8601String());
    }

    return _SqlFilter(
      sql: filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}',
      args: args,
    );
  }

  double _double(Object? value) => ((value as num?) ?? 0).toDouble();

  int _int(Object? value) => ((value as num?) ?? 0).toInt();
}

class _SqlFilter {
  const _SqlFilter({required this.sql, required this.args});

  final String sql;
  final List<Object?> args;
}
