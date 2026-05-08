import 'dart:io';

import 'package:caffe/core/database/database_migrations.dart';
import 'package:caffe/core/database/database_seed_data.dart';
import 'package:caffe/core/database/database_tables.dart';
import 'package:caffe/core/database/app_database.dart';
import 'package:caffe/shared/models/customer_model.dart';
import 'package:caffe/shared/models/order_item_model.dart';
import 'package:caffe/shared/models/order_model.dart';
import 'package:caffe/shared/repositories/customer_repository.dart';
import 'package:caffe/shared/repositories/order_repository.dart';
import 'package:caffe/shared/repositories/settings_repository.dart';
import 'package:caffe/features/pos/application/pos_checkout_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('SQLite schema initializes and seed data is inserted', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);

    await DatabaseMigrations.create(db);
    await DatabaseSeedData.insertInitialData(db);

    final categories = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.categories}'),
    );
    final menuItems = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.menuItems}'),
    );
    final settings = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.settings}'),
    );
    final cafeName = await db.query(
      DatabaseTables.settings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['cafe_name'],
      limit: 1,
    );

    expect(categories, 7);
    expect(menuItems, 25);
    expect(settings, 7);
    expect(cafeName.single['value'], 'كافيه النيل');
  });

  test('AppDatabase initializes SQLite and applies seed data', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'caffe_db_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDirectory.path,
    );
    addTearDown(() async {
      await AppDatabase.instance.close();
      await tempDirectory.delete(recursive: true);
    });

    final db = await AppDatabase.instance.initialize();
    final categories = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.categories}'),
    );
    final menuItems = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseTables.menuItems}'),
    );

    expect(db.isOpen, isTrue);
    expect(categories, 7);
    expect(menuItems, 25);
  });

  test('CustomerRepository finds a saved customer by phone', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'caffe_customer_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDirectory.path,
    );
    addTearDown(() async {
      await AppDatabase.instance.close();
      await tempDirectory.delete(recursive: true);
    });

    final repository = CustomerRepository(AppDatabase.instance);
    final customerId = await repository.create(
      CustomerModel(
        name: 'عميل اختبار',
        phone: '01012345678',
        address: 'القاهرة',
        notes: 'يفضل القهوة التركي',
        createdAt: DateTime.now(),
      ),
    );

    final customer = await repository.findByPhone('01012345678');

    expect(customer?.id, customerId);
    expect(customer?.name, 'عميل اختبار');
    expect(customer?.phone, '01012345678');
  });

  test(
    'OrderRepository saves order, items, next number, and customer count',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'caffe_order_test_',
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        tempDirectory.path,
      );
      addTearDown(() async {
        await AppDatabase.instance.close();
        await tempDirectory.delete(recursive: true);
      });

      final customers = CustomerRepository(AppDatabase.instance);
      final orders = OrderRepository(AppDatabase.instance);
      final customerId = await customers.create(
        CustomerModel(
          name: 'عميل طلب',
          phone: '01011112222',
          createdAt: DateTime.now(),
        ),
      );

      expect(await orders.getNextOrderNumber(), 1);

      final orderId = await orders.createOrder(
        OrderModel(
          orderNumber: await orders.getNextOrderNumber(),
          customerId: customerId,
          customerName: 'عميل طلب',
          customerPhone: '01011112222',
          tableNumber: '5',
          paymentMethod: 'كاش',
          subtotal: 100,
          discountValue: 10,
          discountType: 'percent',
          discountAmount: 10,
          taxAmount: 12.6,
          total: 102.6,
          createdAt: DateTime.now(),
        ),
        const [
          OrderItemModel(
            orderId: 0,
            menuItemId: 1,
            itemName: 'إسبريسو',
            quantity: 2,
            unitPrice: 50,
            total: 100,
          ),
        ],
      );

      final savedOrder = await orders.getOrderById(orderId);
      final savedItems = await orders.getOrderItems(orderId);
      final updatedCustomer = await customers.findById(customerId);

      expect(savedOrder?.orderNumber, 1);
      expect(savedOrder?.customerName, 'عميل طلب');
      expect(savedItems, hasLength(1));
      expect(savedItems.single.itemName, 'إسبريسو');
      expect(savedItems.single.quantity, 2);
      expect(updatedCustomer?.orderCount, 1);
      expect(await orders.getNextOrderNumber(), 2);
      expect(await orders.getTodayOrdersCount(), 1);
      expect(await orders.getTodaySales(), 102.6);
    },
  );

  test(
    'OrderRepository filters, searches, loads details, and reopens invoice data',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'caffe_history_test_',
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        tempDirectory.path,
      );
      addTearDown(() async {
        await AppDatabase.instance.close();
        await tempDirectory.delete(recursive: true);
      });

      final customers = CustomerRepository(AppDatabase.instance);
      final orders = OrderRepository(AppDatabase.instance);
      final settings = SettingsRepository(AppDatabase.instance);
      final customerId = await customers.create(
        CustomerModel(
          name: 'منى سعيد',
          phone: '01099998888',
          createdAt: DateTime.now(),
        ),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10);
      final yesterday = today.subtract(const Duration(days: 1));

      final firstOrderId = await orders.createOrder(
        OrderModel(
          orderNumber: 1,
          customerId: customerId,
          customerName: 'منى سعيد',
          customerPhone: '01099998888',
          paymentMethod: 'فيزا',
          subtotal: 80,
          discountAmount: 0,
          taxAmount: 11.2,
          total: 91.2,
          createdAt: today,
        ),
        const [
          OrderItemModel(
            orderId: 0,
            menuItemId: 2,
            itemName: 'لاتيه',
            quantity: 1,
            unitPrice: 80,
            total: 80,
          ),
        ],
      );
      await orders.createOrder(
        OrderModel(
          orderNumber: 2,
          customerName: 'عميل عادي',
          customerPhone: '01022223333',
          paymentMethod: 'كاش',
          subtotal: 45,
          discountAmount: 0,
          taxAmount: 0,
          total: 45,
          createdAt: yesterday,
        ),
        const [
          OrderItemModel(
            orderId: 0,
            menuItemId: 1,
            itemName: 'إسبريسو',
            quantity: 1,
            unitPrice: 45,
            total: 45,
          ),
        ],
      );

      final todayOrders = await orders.getOrdersByDateRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day + 1),
      );
      final searchByInvoice = await orders.searchOrders('1');
      final searchByCustomer = await orders.searchOrders('منى');
      final searchByPhone = await orders.searchOrders('0102222');
      final customerOrders = await orders.getOrdersByCustomer(customerId);
      final details = await orders.getOrderWithItems(firstOrderId);

      expect(todayOrders.map((order) => order.orderNumber), [1]);
      expect(searchByInvoice.map((order) => order.orderNumber), contains(1));
      expect(searchByCustomer.single.customerName, 'منى سعيد');
      expect(searchByPhone.single.orderNumber, 2);
      expect(customerOrders, hasLength(1));
      expect(details?.items.single.itemName, 'لاتيه');

      final checkoutService = PosCheckoutService(
        orderRepository: orders,
        settingsRepository: settings,
      );
      final reopenedInvoice = await checkoutService.loadInvoice(firstOrderId);

      expect(reopenedInvoice?.order.orderNumber, 1);
      expect(reopenedInvoice?.items.single.itemName, 'لاتيه');
      expect(reopenedInvoice?.cafeName, 'كافيه النيل');
      expect(reopenedInvoice?.footerMessage, 'شكراً لزيارتكم');
    },
  );
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
