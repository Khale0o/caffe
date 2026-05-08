import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_tables.dart';
import '../models/customer_model.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(AppDatabase.instance);
});

class CustomerRepository {
  const CustomerRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<Database> get _db => _appDatabase.database;

  Future<int> create(CustomerModel customer) async {
    final db = await _db;
    final map = customer.toMap()..remove('id');
    return db.insert(DatabaseTables.customers, map);
  }

  Future<CustomerModel?> findById(int id) async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.customers,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CustomerModel.fromMap(rows.first);
  }

  Future<CustomerModel?> findByPhone(String phone) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) return null;

    final db = await _db;
    final rows = await db.query(
      DatabaseTables.customers,
      where: 'phone = ?',
      whereArgs: [normalizedPhone],
      limit: 1,
    );
    return rows.isEmpty ? null : CustomerModel.fromMap(rows.first);
  }

  Future<List<CustomerModel>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      DatabaseTables.customers,
      orderBy: 'created_at DESC',
    );
    return rows.map(CustomerModel.fromMap).toList();
  }

  Future<int> update(CustomerModel customer) async {
    final db = await _db;
    return db.update(
      DatabaseTables.customers,
      customer.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete(
      DatabaseTables.customers,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> count() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${DatabaseTables.customers}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
