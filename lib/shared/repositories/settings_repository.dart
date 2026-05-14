import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(AppDatabase.instance);
});

class SettingsRepository {
  const SettingsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<Database> get _db => _appDatabase.database;

  Future<String?> getValue(String key) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.settings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<Map<String, String?>> getAll() async {
    final db = await _db;
    final rows = await db.query(DatabaseTables.settings, orderBy: 'key ASC');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String?,
    };
  }

  Future<void> setValue(String key, String? value) async {
    final db = await _db;
    await db.insert(DatabaseTables.settings, {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setValues(Map<String, String?> values) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final entry in values.entries) {
        await txn.insert(DatabaseTables.settings, {
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
