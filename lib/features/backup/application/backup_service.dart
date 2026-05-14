import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_tables.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(appDatabase: AppDatabase.instance);
});

class BackupService {
  BackupService({
    required AppDatabase appDatabase,
    Directory? backupsDirectory,
    DateTime Function()? clock,
  }) : _appDatabase = appDatabase,
       _backupsDirectoryOverride = backupsDirectory,
       _clock = clock ?? DateTime.now;

  final AppDatabase _appDatabase;
  final Directory? _backupsDirectoryOverride;
  final DateTime Function() _clock;

  static final _backupNameFormat = DateFormat('yyyy_MM_dd_HH_mm_ss');
  static const _requiredTables = [
    DatabaseTables.customers,
    DatabaseTables.categories,
    DatabaseTables.menuItems,
    DatabaseTables.orders,
    DatabaseTables.orderItems,
    DatabaseTables.settings,
  ];

  String backupFileName(DateTime dateTime) {
    return 'cafe_backup_${_backupNameFormat.format(dateTime)}.db';
  }

  Future<Directory> backupsDirectory() async {
    if (_backupsDirectoryOverride != null) {
      await _backupsDirectoryOverride.create(recursive: true);
      return _backupsDirectoryOverride;
    }

    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'cafe_pos_backups'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<BackupFileInfo> createBackup() async {
    final directory = await backupsDirectory();
    await _appDatabase.database;
    final dbPath = await _appDatabase.databasePath;
    final source = File(dbPath);
    if (!await source.exists()) {
      throw const BackupException('تعذر العثور على قاعدة البيانات الحالية');
    }

    final backupPath = p.join(directory.path, backupFileName(_clock()));
    await _appDatabase.close();
    try {
      await source.copy(backupPath);
    } finally {
      await _appDatabase.initialize();
    }

    final backup = File(backupPath);
    final validation = await validateBackupFile(backup);
    if (!validation.isValid) {
      await backup.delete().catchError((_) => backup);
      throw BackupException(validation.message ?? 'تعذر التحقق من النسخة');
    }

    return BackupFileInfo.fromFile(backup);
  }

  Future<List<BackupFileInfo>> listBackups() async {
    final directory = await backupsDirectory();
    final files = await directory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.db'))
        .cast<File>()
        .toList();
    final backups = <BackupFileInfo>[];
    for (final file in files) {
      if (await file.exists()) {
        backups.add(await BackupFileInfo.fromFile(file));
      }
    }
    backups.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return backups;
  }

  Future<BackupValidationResult> validateBackupFile(File file) async {
    if (!await file.exists()) {
      return const BackupValidationResult.invalid('ملف النسخة غير موجود');
    }
    if (p.extension(file.path).toLowerCase() != '.db') {
      return const BackupValidationResult.invalid('صيغة الملف غير مدعومة');
    }
    if (await file.length() == 0) {
      return const BackupValidationResult.invalid('ملف النسخة فارغ');
    }

    Database? database;
    try {
      database = await openDatabase(file.path, readOnly: true);
      final integrity = await database.rawQuery('PRAGMA integrity_check');
      final integrityValue = integrity.isEmpty
          ? null
          : integrity.first.values.first?.toString().toLowerCase();
      if (integrityValue != 'ok') {
        return const BackupValidationResult.invalid('ملف النسخة تالف');
      }

      final rows = await database.query(
        'sqlite_master',
        columns: ['name'],
        where: 'type = ?',
        whereArgs: ['table'],
      );
      final tableNames = rows.map((row) => row['name'] as String).toSet();
      final missingTables = _requiredTables.where(
        (table) => !tableNames.contains(table),
      );
      if (missingTables.isNotEmpty) {
        return const BackupValidationResult.invalid(
          'ملف النسخة لا يطابق قاعدة بيانات التطبيق',
        );
      }

      return const BackupValidationResult.valid();
    } catch (_) {
      return const BackupValidationResult.invalid(
        'تعذر قراءة ملف النسخة الاحتياطية',
      );
    } finally {
      await database?.close();
    }
  }

  Future<void> restoreBackup(File backupFile) async {
    final validation = await validateBackupFile(backupFile);
    if (!validation.isValid) {
      throw BackupException(validation.message ?? 'نسخة احتياطية غير صالحة');
    }

    final dbPath = await _appDatabase.databasePath;
    final target = File(dbPath);
    final restoreSafetyCopy = File('$dbPath.restore_safety_copy');

    await _appDatabase.close();
    try {
      if (await target.exists()) {
        await target.copy(restoreSafetyCopy.path);
      }
      await backupFile.copy(target.path);
      await _appDatabase.initialize();
      if (await restoreSafetyCopy.exists()) {
        await restoreSafetyCopy.delete();
      }
    } catch (_) {
      await _appDatabase.close();
      if (await restoreSafetyCopy.exists()) {
        await restoreSafetyCopy.copy(target.path);
        await restoreSafetyCopy.delete();
      }
      await _appDatabase.initialize();
      throw const BackupException('تعذر استعادة النسخة الاحتياطية');
    }
  }

  Future<void> deleteBackup(File file) async {
    if (!await file.exists()) return;
    final directory = await backupsDirectory();
    final backupDir = p.normalize(directory.absolute.path);
    final filePath = p.normalize(file.absolute.path);
    if (!p.isWithin(backupDir, filePath) && backupDir != p.dirname(filePath)) {
      throw const BackupException('لا يمكن حذف ملف خارج مجلد النسخ');
    }
    await file.delete();
  }
}

class BackupFileInfo {
  const BackupFileInfo({
    required this.file,
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final File file;
  final String name;
  final int sizeBytes;
  final DateTime modifiedAt;

  static Future<BackupFileInfo> fromFile(File file) async {
    final stat = await file.stat();
    return BackupFileInfo(
      file: file,
      name: p.basename(file.path),
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
    );
  }
}

class BackupValidationResult {
  const BackupValidationResult._({required this.isValid, this.message});

  const BackupValidationResult.valid() : this._(isValid: true);

  const BackupValidationResult.invalid(String message)
    : this._(isValid: false, message: message);

  final bool isValid;
  final String? message;
}

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;
}
