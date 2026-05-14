import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backup_service.dart';

final backupListProvider = FutureProvider<List<BackupFileInfo>>((ref) {
  return ref.watch(backupServiceProvider).listBackups();
});

final backupActionsProvider =
    NotifierProvider<BackupActionsController, BackupActionsState>(
      BackupActionsController.new,
    );

class BackupActionsController extends Notifier<BackupActionsState> {
  @override
  BackupActionsState build() => const BackupActionsState();

  Future<BackupFileInfo?> createBackup() async {
    if (state.isCreating || state.isRestoring) return null;
    state = state.copyWith(isCreating: true);
    try {
      final backup = await ref.read(backupServiceProvider).createBackup();
      ref.invalidate(backupListProvider);
      return backup;
    } finally {
      state = state.copyWith(isCreating: false);
    }
  }

  Future<void> restoreBackup(File file) async {
    if (state.isCreating || state.isRestoring) return;
    state = state.copyWith(isRestoring: true, restoringPath: file.path);
    try {
      await ref.read(backupServiceProvider).restoreBackup(file);
      ref.invalidate(backupListProvider);
    } finally {
      state = state.copyWith(isRestoring: false, restoringPath: null);
    }
  }

  Future<void> deleteBackup(File file) async {
    if (state.isCreating || state.isRestoring || state.deletingPath != null) {
      return;
    }
    state = state.copyWith(deletingPath: file.path);
    try {
      await ref.read(backupServiceProvider).deleteBackup(file);
      ref.invalidate(backupListProvider);
    } finally {
      state = state.copyWith(deletingPath: null);
    }
  }
}

class BackupActionsState {
  const BackupActionsState({
    this.isCreating = false,
    this.isRestoring = false,
    this.restoringPath,
    this.deletingPath,
  });

  final bool isCreating;
  final bool isRestoring;
  final String? restoringPath;
  final String? deletingPath;

  bool get isBusy => isCreating || isRestoring || deletingPath != null;

  BackupActionsState copyWith({
    bool? isCreating,
    bool? isRestoring,
    String? restoringPath,
    String? deletingPath,
  }) {
    return BackupActionsState(
      isCreating: isCreating ?? this.isCreating,
      isRestoring: isRestoring ?? this.isRestoring,
      restoringPath: restoringPath,
      deletingPath: deletingPath,
    );
  }
}
