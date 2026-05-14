import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_migrations.dart';
import 'database_seed_data.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    return initialize();
  }

  Future<String> get databasePath => _databasePath();

  Future<Database> initialize() async {
    if (_database != null) return _database!;

    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await _databasePath();
    _database = await openDatabase(
      dbPath,
      version: DatabaseMigrations.currentVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await DatabaseMigrations.create(db);
        await DatabaseSeedData.insertInitialData(db);
      },
      onUpgrade: DatabaseMigrations.upgrade,
    );

    return _database!;
  }

  Future<String> _databasePath() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final directory = await getApplicationSupportDirectory();
      return p.join(directory.path, 'cafe_pos.db');
    }

    final databasesPath = await getDatabasesPath();
    return p.join(databasesPath, 'cafe_pos.db');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
