import 'package:sqflite/sqflite.dart';

import 'database_tables.dart';

class DatabaseMigrations {
  const DatabaseMigrations._();

  static const currentVersion = 1;

  static Future<void> create(Database db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseTables.customers} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT UNIQUE,
        address TEXT,
        notes TEXT,
        order_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.categories} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT,
        color TEXT,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.menuItems} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        description TEXT,
        is_available INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (category_id) REFERENCES ${DatabaseTables.categories} (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.orders} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number INTEGER NOT NULL,
        customer_id INTEGER,
        customer_name TEXT,
        customer_phone TEXT,
        table_number TEXT,
        payment_method TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount_value REAL DEFAULT 0,
        discount_type TEXT DEFAULT 'percent',
        discount_amount REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        total REAL NOT NULL,
        status TEXT DEFAULT 'completed',
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES ${DatabaseTables.customers} (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.orderItems} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        menu_item_id INTEGER,
        item_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (order_id) REFERENCES ${DatabaseTables.orders} (id),
        FOREIGN KEY (menu_item_id) REFERENCES ${DatabaseTables.menuItems} (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.settings} (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_menu_items_category ON ${DatabaseTables.menuItems} (category_id)',
    );
    await db.execute(
      'CREATE INDEX idx_orders_created_at ON ${DatabaseTables.orders} (created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_order_items_order ON ${DatabaseTables.orderItems} (order_id)',
    );
  }

  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Future migrations will be applied incrementally from here.
  }
}
