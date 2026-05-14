import 'dart:async';
import 'dart:io';

import 'package:caffe/core/database/app_database.dart';
import 'package:caffe/features/backup/application/backup_providers.dart';
import 'package:caffe/features/backup/application/backup_service.dart';
import 'package:caffe/shared/models/customer_model.dart';
import 'package:caffe/shared/repositories/customer_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('backup filename generation uses a stable timestamp format', () {
    final service = BackupService(
      appDatabase: AppDatabase.instance,
      clock: () => DateTime(2026, 5, 14, 10, 30, 45),
    );

    expect(
      service.backupFileName(DateTime(2026, 5, 14, 10, 30, 45)),
      'cafe_backup_2026_05_14_10_30_45.db',
    );
  });

  test(
    'backup validation rejects missing, empty, and non-database files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'caffe_backup_invalid_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final service = BackupService(
        appDatabase: AppDatabase.instance,
        backupsDirectory: directory,
      );

      final missing = await service.validateBackupFile(
        File('${directory.path}/missing.db'),
      );
      final empty = File('${directory.path}/empty.db');
      await empty.create();
      final text = File('${directory.path}/notes.txt');
      await text.writeAsString('not a sqlite database');

      expect(missing.isValid, isFalse);
      expect((await service.validateBackupFile(empty)).isValid, isFalse);
      expect((await service.validateBackupFile(text)).isValid, isFalse);
    },
  );

  test(
    'backup creation, list loading, and restore replace current data',
    () async {
      final appDirectory = await Directory.systemTemp.createTemp(
        'caffe_backup_app_',
      );
      final backupsDirectory = await Directory.systemTemp.createTemp(
        'caffe_backup_files_',
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        appDirectory.path,
      );
      addTearDown(() async {
        await AppDatabase.instance.close();
        await appDirectory.delete(recursive: true);
        await backupsDirectory.delete(recursive: true);
      });

      final customers = CustomerRepository(AppDatabase.instance);
      final service = BackupService(
        appDatabase: AppDatabase.instance,
        backupsDirectory: backupsDirectory,
        clock: () => DateTime(2026, 5, 14, 10, 30),
      );

      await customers.create(
        CustomerModel(
          name: 'قبل النسخة',
          phone: '0101',
          createdAt: DateTime(2026),
        ),
      );
      final backup = await service.createBackup();

      await customers.create(
        CustomerModel(
          name: 'بعد النسخة',
          phone: '0102',
          createdAt: DateTime(2026),
        ),
      );
      expect(await customers.count(), 2);

      final backups = await service.listBackups();
      expect(backups, hasLength(1));
      expect(backups.single.name, backup.name);
      expect(backups.single.sizeBytes, greaterThan(0));

      await service.restoreBackup(backup.file);
      expect(await customers.count(), 1);
      expect((await customers.findByPhone('0101'))?.name, 'قبل النسخة');
      expect(await customers.findByPhone('0102'), isNull);
    },
  );

  test(
    'restore rejects invalid backup without breaking active database',
    () async {
      final appDirectory = await Directory.systemTemp.createTemp(
        'caffe_backup_restore_invalid_app_',
      );
      final backupsDirectory = await Directory.systemTemp.createTemp(
        'caffe_backup_restore_invalid_files_',
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        appDirectory.path,
      );
      addTearDown(() async {
        await AppDatabase.instance.close();
        await appDirectory.delete(recursive: true);
        await backupsDirectory.delete(recursive: true);
      });

      final customers = CustomerRepository(AppDatabase.instance);
      final service = BackupService(
        appDatabase: AppDatabase.instance,
        backupsDirectory: backupsDirectory,
      );
      await customers.create(
        CustomerModel(
          name: 'بيانات سليمة',
          phone: '0103',
          createdAt: DateTime(2026),
        ),
      );
      final invalid = File('${backupsDirectory.path}/invalid.db');
      await invalid.writeAsString('broken');

      await expectLater(
        service.restoreBackup(invalid),
        throwsA(isA<BackupException>()),
      );
      expect(await customers.count(), 1);
    },
  );

  test(
    'backup action controller prevents duplicate create operations',
    () async {
      final fakeService = _FakeBackupService();
      final container = ProviderContainer(
        overrides: [backupServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final controller = container.read(backupActionsProvider.notifier);
      final first = controller.createBackup();
      final second = controller.createBackup();

      expect(await second, isNull);
      fakeService.completeCreate();
      expect(await first, isNotNull);
      expect(fakeService.createCalls, 1);
    },
  );
}

class _FakeBackupService extends BackupService {
  _FakeBackupService() : super(appDatabase: AppDatabase.instance);

  int createCalls = 0;
  final _createCompleter = Completer<BackupFileInfo>();

  @override
  Future<BackupFileInfo> createBackup() {
    createCalls++;
    return _createCompleter.future;
  }

  void completeCreate() {
    final file = File('${Directory.systemTemp.path}/fake_backup.db');
    _createCompleter.complete(
      BackupFileInfo(
        file: file,
        name: 'fake_backup.db',
        sizeBytes: 12,
        modifiedAt: DateTime(2026),
      ),
    );
  }
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}
