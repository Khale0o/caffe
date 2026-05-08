import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_tables.dart';

class DatabaseSeedData {
  const DatabaseSeedData._();

  static Future<void> insertInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();

    final categories = [
      ('قهوة', '☕', '#C89B3C'),
      ('مشروبات ساخنة', '🫖', '#8B5E34'),
      ('مشروبات باردة', '🧊', '#4B8FAD'),
      ('عصائر', '🍹', '#D9822B'),
      ('حلويات', '🍰', '#C77D95'),
      ('سناكس', '🥐', '#B7791F'),
      ('إضافات', '➕', '#9A8F82'),
    ];

    for (var i = 0; i < categories.length; i++) {
      final category = categories[i];
      batch.insert(DatabaseTables.categories, {
        'name': category.$1,
        'icon': category.$2,
        'color': category.$3,
        'sort_order': i,
        'is_active': 1,
      });
    }

    await batch.commit(noResult: true);

    final categoryRows = await db.query(DatabaseTables.categories);
    final categoryIds = {
      for (final row in categoryRows) row['name'] as String: row['id'] as int,
    };

    final menuItems = <({String name, String category, double price})>[
      (name: 'إسبريسو', category: 'قهوة', price: 45),
      (name: 'أمريكانو', category: 'قهوة', price: 55),
      (name: 'كابتشينو', category: 'قهوة', price: 70),
      (name: 'لاتيه', category: 'قهوة', price: 75),
      (name: 'موكا', category: 'قهوة', price: 80),
      (name: 'قهوة تركي', category: 'قهوة', price: 45),
      (name: 'شاي', category: 'مشروبات ساخنة', price: 30),
      (name: 'شاي نعناع', category: 'مشروبات ساخنة', price: 35),
      (name: 'هوت شوكليت', category: 'مشروبات ساخنة', price: 75),
      (name: 'سحلب', category: 'مشروبات ساخنة', price: 65),
      (name: 'آيس لاتيه', category: 'مشروبات باردة', price: 80),
      (name: 'آيس موكا', category: 'مشروبات باردة', price: 85),
      (name: 'ليمون نعناع', category: 'عصائر', price: 60),
      (name: 'عصير مانجو', category: 'عصائر', price: 70),
      (name: 'عصير فراولة', category: 'عصائر', price: 70),
      (name: 'عصير برتقال', category: 'عصائر', price: 65),
      (name: 'تشيز كيك', category: 'حلويات', price: 95),
      (name: 'براونيز', category: 'حلويات', price: 80),
      (name: 'وافل', category: 'حلويات', price: 110),
      (name: 'كرواسون', category: 'سناكس', price: 55),
      (name: 'توست جبنة', category: 'سناكس', price: 75),
      (name: 'شوت إسبريسو', category: 'إضافات', price: 25),
      (name: 'كراميل', category: 'إضافات', price: 15),
      (name: 'فانيليا', category: 'إضافات', price: 15),
      (name: 'كريمة', category: 'إضافات', price: 20),
    ];

    final seedBatch = db.batch();
    for (final item in menuItems) {
      seedBatch.insert(DatabaseTables.menuItems, {
        'category_id': categoryIds[item.category],
        'name': item.name,
        'price': item.price,
        'description': null,
        'is_available': 1,
        'created_at': now,
        'updated_at': null,
      });
    }

    final settings = {
      'cafe_name': 'كافيه النيل',
      'cafe_phone': '01000000000',
      'cafe_address': 'القاهرة، مصر',
      'vat_enabled': 'true',
      'vat_percent': '14',
      'admin_pin': '1234',
      'invoice_footer': 'شكراً لزيارتكم',
    };

    for (final entry in settings.entries) {
      seedBatch.insert(DatabaseTables.settings, {
        'key': entry.key,
        'value': entry.value,
      });
    }

    await seedBatch.commit(noResult: true);
  }
}
