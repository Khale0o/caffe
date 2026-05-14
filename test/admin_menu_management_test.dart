import 'dart:io';

import 'package:caffe/core/database/app_database.dart';
import 'package:caffe/features/admin/application/admin_validators.dart';
import 'package:caffe/shared/models/category_model.dart';
import 'package:caffe/shared/models/menu_item_model.dart';
import 'package:caffe/shared/repositories/menu_repository.dart';
import 'package:caffe/shared/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('admin PIN setting is read and updated locally', () async {
    final tempDirectory = await _prepareDatabase('caffe_admin_pin_test_');
    addTearDown(() => _cleanup(tempDirectory));

    final settings = SettingsRepository(AppDatabase.instance);

    expect(await settings.getValue('admin_pin'), '1234');

    await settings.setValues({'admin_pin': '2468'});

    expect(await settings.getValue('admin_pin'), '2468');
    expect(
      AdminValidators.requiredText('', 'الرقم السري مطلوب'),
      'الرقم السري مطلوب',
    );
    expect(AdminValidators.requiredText('2468', 'الرقم السري مطلوب'), isNull);
  });

  test('category add, edit, deactivate, and item safety checks work', () async {
    final tempDirectory = await _prepareDatabase('caffe_admin_category_test_');
    addTearDown(() => _cleanup(tempDirectory));

    final menu = MenuRepository(AppDatabase.instance);
    final categoryId = await menu.createCategory(
      const CategoryModel(
        name: 'قسم اختبار',
        icon: '⭐',
        color: '#FFFFFF',
        sortOrder: 99,
      ),
    );

    await menu.updateCategory(
      const CategoryModel(id: null, name: 'unused').copyWith(
        id: categoryId,
        name: 'قسم معدل',
        icon: '✨',
        color: '#C89B3C',
        sortOrder: 2,
        isActive: true,
      ),
    );

    var categories = await menu.getCategories();
    final updated = categories.firstWhere(
      (category) => category.id == categoryId,
    );
    expect(updated.name, 'قسم معدل');
    expect(updated.sortOrder, 2);
    expect(await menu.categoryHasMenuItems(categoryId), isFalse);

    await menu.createMenuItem(
      MenuItemModel(
        categoryId: categoryId,
        name: 'صنف داخل القسم',
        price: 25,
        createdAt: DateTime.now(),
      ),
    );

    expect(await menu.categoryHasMenuItems(categoryId), isTrue);

    await menu.setCategoryActive(categoryId, false);

    categories = await menu.getCategories(activeOnly: true);
    expect(categories.any((category) => category.id == categoryId), isFalse);
  });

  test('item add, edit, availability toggle, and POS filters work', () async {
    final tempDirectory = await _prepareDatabase('caffe_admin_item_test_');
    addTearDown(() => _cleanup(tempDirectory));

    final menu = MenuRepository(AppDatabase.instance);
    final categoryId = await menu.createCategory(
      const CategoryModel(name: 'قسم متاح', sortOrder: 1),
    );
    final inactiveCategoryId = await menu.createCategory(
      const CategoryModel(name: 'قسم متوقف', sortOrder: 2, isActive: false),
    );

    final itemId = await menu.createMenuItem(
      MenuItemModel(
        categoryId: categoryId,
        name: 'لاتيه اختبار',
        price: 60,
        description: 'وصف قديم',
        createdAt: DateTime.now(),
      ),
    );
    final hiddenItemId = await menu.createMenuItem(
      MenuItemModel(
        categoryId: categoryId,
        name: 'صنف غير متاح',
        price: 40,
        isAvailable: false,
        createdAt: DateTime.now(),
      ),
    );

    await menu.updateMenuItem(
      MenuItemModel(
        id: itemId,
        categoryId: categoryId,
        name: 'لاتيه معدل',
        price: 65,
        description: 'وصف جديد',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await menu.setMenuItemAvailable(itemId, false);
    await menu.setMenuItemAvailable(hiddenItemId, true);

    final availableItems = await menu.getMenuItems(availableOnly: true);
    final activeCategories = await menu.getCategories(activeOnly: true);
    final searchResults = await menu.getMenuItems(searchText: 'لاتيه');

    expect(availableItems.any((item) => item.id == itemId), isFalse);
    expect(availableItems.any((item) => item.id == hiddenItemId), isTrue);
    expect(
      activeCategories.any((category) => category.id == categoryId),
      isTrue,
    );
    expect(
      activeCategories.any((category) => category.id == inactiveCategoryId),
      isFalse,
    );
    expect(searchResults.singleWhere((item) => item.id == itemId).price, 65);
    expect(AdminValidators.positivePrice('0'), 'السعر يجب أن يكون أكبر من صفر');
    expect(AdminValidators.positivePrice('12.5'), isNull);
    expect(AdminValidators.requiredCategory(null), 'القسم مطلوب');
    expect(
      AdminValidators.vatPercent('101'),
      'نسبة الضريبة يجب أن تكون بين 0 و 100',
    );
    expect(AdminValidators.vatPercent('14'), isNull);
  });
}

Future<Directory> _prepareDatabase(String prefix) async {
  final tempDirectory = await Directory.systemTemp.createTemp(prefix);
  PathProviderPlatform.instance = _FakePathProviderPlatform(tempDirectory.path);
  return tempDirectory;
}

Future<void> _cleanup(Directory tempDirectory) async {
  await AppDatabase.instance.close();
  await tempDirectory.delete(recursive: true);
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
