import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../models/order_item_model.dart';
import '../models/order_model.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(AppDatabase.instance);
});

class OrderRepository {
  const OrderRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<Database> get _db => _appDatabase.database;

  Future<int> createOrder(OrderModel order, List<OrderItemModel> items) async {
    if (items.isEmpty) {
      throw ArgumentError('Order must contain at least one item.');
    }

    final db = await _db;
    return db.transaction((txn) async {
      final orderId = await txn.insert(
        DatabaseTables.orders,
        order.toMap()..remove('id'),
      );
      for (final item in items) {
        await txn.insert(
          DatabaseTables.orderItems,
          item.copyWith(orderId: orderId).toMap()..remove('id'),
        );
      }

      if (order.customerId != null) {
        await txn.rawUpdate(
          '''
          UPDATE ${DatabaseTables.customers}
          SET order_count = order_count + 1,
              updated_at = ?
          WHERE id = ?
          ''',
          [DateTime.now().toIso8601String(), order.customerId],
        );
      }

      return orderId;
    });
  }

  Future<OrderModel?> getOrderById(int id) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.orders,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : OrderModel.fromMap(rows.first);
  }

  Future<OrderModel?> findById(int id) => getOrderById(id);

  Future<List<OrderModel>> getRecentOrders({int limit = 50}) async {
    return getOrders(limit: limit);
  }

  Future<List<OrderModel>> recentOrders({int limit = 50}) {
    return getRecentOrders(limit: limit);
  }

  Future<List<OrderModel>> getOrders({
    DateTime? start,
    DateTime? end,
    String? search,
    int? customerId,
    int limit = 100,
  }) async {
    final db = await _db;
    final query = _buildOrderQuery(
      start: start,
      end: end,
      search: search,
      customerId: customerId,
    );
    final rows = await db.query(
      DatabaseTables.orders,
      where: query.where,
      whereArgs: query.args,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(OrderModel.fromMap).toList();
  }

  Future<List<OrderModel>> searchOrders(String search, {int limit = 100}) {
    return getOrders(search: search, limit: limit);
  }

  Future<List<OrderModel>> getOrdersByDateRange({
    required DateTime start,
    required DateTime end,
    int limit = 100,
  }) {
    return getOrders(start: start, end: end, limit: limit);
  }

  Future<List<OrderModel>> getOrdersByCustomer(
    int customerId, {
    int limit = 100,
  }) {
    return getOrders(customerId: customerId, limit: limit);
  }

  Future<List<OrderItemModel>> getOrderItems(int orderId) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.orderItems,
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'id ASC',
    );
    return rows.map(OrderItemModel.fromMap).toList();
  }

  Future<List<OrderItemModel>> orderItems(int orderId) =>
      getOrderItems(orderId);

  Future<OrderWithItems?> getOrderWithItems(int orderId) async {
    final order = await getOrderById(orderId);
    if (order == null) return null;
    final items = await getOrderItems(orderId);
    return OrderWithItems(order: order, items: items);
  }

  Future<int> getTodayOrdersCount() async {
    final db = await _db;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM ${DatabaseTables.orders}
      WHERE created_at >= ? AND created_at < ?
      ''',
      [start, end],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> todayOrdersCount() => getTodayOrdersCount();

  Future<double> getTodaySales() async {
    final db = await _db;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total), 0) AS total
      FROM ${DatabaseTables.orders}
      WHERE created_at >= ? AND created_at < ?
      ''',
      [start, end],
    );
    return ((result.first['total'] as num?) ?? 0).toDouble();
  }

  Future<double> todaySalesTotal() => getTodaySales();

  Future<int> getNextOrderNumber() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(order_number), 0) + 1 AS next_number FROM ${DatabaseTables.orders}',
    );
    return ((result.first['next_number'] as num?) ?? 1).toInt();
  }

  Future<int> nextOrderNumber() => getNextOrderNumber();

  _OrderQuery _buildOrderQuery({
    DateTime? start,
    DateTime? end,
    String? search,
    int? customerId,
  }) {
    final filters = <String>[];
    final args = <Object?>[];

    if (start != null) {
      filters.add('created_at >= ?');
      args.add(start.toIso8601String());
    }

    if (end != null) {
      filters.add('created_at < ?');
      args.add(end.toIso8601String());
    }

    if (customerId != null) {
      filters.add('customer_id = ?');
      args.add(customerId);
    }

    final normalizedSearch = search?.trim();
    if (normalizedSearch != null && normalizedSearch.isNotEmpty) {
      final invoiceNumber = int.tryParse(normalizedSearch);
      if (invoiceNumber != null) {
        filters.add(
          '(order_number = ? OR customer_name LIKE ? OR customer_phone LIKE ?)',
        );
        args.add(invoiceNumber);
      } else {
        filters.add('(customer_name LIKE ? OR customer_phone LIKE ?)');
      }
      args.add('%$normalizedSearch%');
      args.add('%$normalizedSearch%');
    }

    return _OrderQuery(
      where: filters.isEmpty ? null : filters.join(' AND '),
      args: args.isEmpty ? null : args,
    );
  }
}

class OrderWithItems {
  const OrderWithItems({required this.order, required this.items});

  final OrderModel order;
  final List<OrderItemModel> items;
}

class _OrderQuery {
  const _OrderQuery({required this.where, required this.args});

  final String? where;
  final List<Object?>? args;
}
