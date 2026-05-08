import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../models/category_model.dart';
import '../models/menu_item_model.dart';

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(AppDatabase.instance);
});

class MenuRepository {
  const MenuRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<Database> get _db => _appDatabase.database;

  Future<List<CategoryModel>> getCategories({bool activeOnly = false}) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.categories,
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<int> createCategory(CategoryModel category) async {
    final db = await _db;
    return db.insert(DatabaseTables.categories, category.toMap()..remove('id'));
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await _db;
    return db.update(
      DatabaseTables.categories,
      category.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await _db;
    return db.delete(
      DatabaseTables.categories,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<MenuItemModel>> getMenuItems({
    int? categoryId,
    bool availableOnly = false,
  }) async {
    final db = await _db;
    final filters = <String>[];
    final args = <Object?>[];

    if (categoryId != null) {
      filters.add('category_id = ?');
      args.add(categoryId);
    }
    if (availableOnly) {
      filters.add('is_available = ?');
      args.add(1);
    }

    final rows = await db.query(
      DatabaseTables.menuItems,
      where: filters.isEmpty ? null : filters.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
    return rows.map(MenuItemModel.fromMap).toList();
  }

  Future<int> createMenuItem(MenuItemModel item) async {
    final db = await _db;
    return db.insert(DatabaseTables.menuItems, item.toMap()..remove('id'));
  }

  Future<int> updateMenuItem(MenuItemModel item) async {
    final db = await _db;
    return db.update(
      DatabaseTables.menuItems,
      item.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteMenuItem(int id) async {
    final db = await _db;
    return db.delete(
      DatabaseTables.menuItems,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> menuItemsCount() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${DatabaseTables.menuItems}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
