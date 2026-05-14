import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/admin/application/admin_providers.dart';
import '../../../features/orders/application/orders_history_providers.dart';
import '../../../features/pos/presentation/pos_screen.dart';
import '../../../features/reports/application/reports_providers.dart';
import '../../../features/welcome/presentation/welcome_screen.dart';
import '../../backup/application/backup_providers.dart';
import '../../backup/application/backup_service.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupsAsync = ref.watch(backupListProvider);
    final actions = ref.watch(backupActionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي'),
        leading: IconButton(
          onPressed: actions.isBusy
              ? null
              : () => context.go(AppRoutes.welcome),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: 'رجوع',
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(backupListProvider),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 36 : 16,
                  vertical: 18,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: backupsAsync.when(
                      data: (backups) => _BackupContent(
                        backups: backups,
                        actions: actions,
                        isWide: isWide,
                      ),
                      loading: () => const SizedBox(
                        height: 320,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stackTrace) => _MessageState(
                        icon: Icons.error_outline_rounded,
                        title: 'تعذر تحميل النسخ الاحتياطية',
                        subtitle: 'حاول تحديث القائمة مرة أخرى',
                        action: OutlinedButton.icon(
                          onPressed: () => ref.invalidate(backupListProvider),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('تحديث'),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BackupContent extends ConsumerWidget {
  const _BackupContent({
    required this.backups,
    required this.actions,
    required this.isWide,
  });

  final List<BackupFileInfo> backups;
  final BackupActionsState actions;
  final bool isWide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastBackup = backups.isEmpty ? null : backups.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusPanel(lastBackup: lastBackup, isWide: isWide),
        const SizedBox(height: 16),
        _ActionPanel(actions: actions),
        const SizedBox(height: 16),
        _Panel(
          title: 'النسخ المتاحة',
          trailing: IconButton.filledTonal(
            onPressed: actions.isBusy
                ? null
                : () => ref.invalidate(backupListProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث القائمة',
          ),
          child: backups.isEmpty
              ? const _MessageState(
                  icon: Icons.folder_off_rounded,
                  title: 'لا توجد نسخ احتياطية',
                  subtitle: 'أنشئ نسخة احتياطية لحفظ بيانات التطبيق محلياً',
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: backups.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _BackupTile(backup: backups[index], actions: actions),
                ),
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.lastBackup, required this.isWide});

  final BackupFileInfo? lastBackup;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatusItem(
        label: 'آخر نسخة احتياطية',
        value: lastBackup == null ? 'لا توجد' : lastBackup!.name,
        icon: Icons.history_rounded,
      ),
      _StatusItem(
        label: 'تاريخ النسخة',
        value: lastBackup == null
            ? '-'
            : AppFormatters.dateTime(lastBackup!.modifiedAt),
        icon: Icons.event_rounded,
      ),
      _StatusItem(
        label: 'حجم النسخة',
        value: lastBackup == null ? '-' : _formatBytes(lastBackup!.sizeBytes),
        icon: Icons.sd_storage_rounded,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in items)
          SizedBox(
            width: isWide ? 360 : double.infinity,
            child: _StatusCard(item: item),
          ),
      ],
    );
  }
}

class _ActionPanel extends ConsumerWidget {
  const _ActionPanel({required this.actions});

  final BackupActionsState actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Panel(
      title: 'إدارة النسخ الاحتياطية',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: actions.isBusy
                ? null
                : () => _createBackup(context, ref),
            icon: actions.isCreating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.backup_rounded),
            label: Text(
              actions.isCreating ? 'جاري إنشاء النسخة' : 'إنشاء نسخة احتياطية',
            ),
          ),
          OutlinedButton.icon(
            onPressed: actions.isBusy
                ? null
                : () => ref.invalidate(backupListProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تحديث القائمة'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup(BuildContext context, WidgetRef ref) async {
    try {
      final backup = await ref
          .read(backupActionsProvider.notifier)
          .createBackup();
      if (!context.mounted || backup == null) return;
      _showMessage(context, 'تم إنشاء نسخة احتياطية: ${backup.name}');
    } on BackupException catch (error) {
      if (context.mounted) _showMessage(context, error.message, isError: true);
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'تعذر إنشاء النسخة الاحتياطية', isError: true);
      }
    }
  }
}

class _BackupTile extends ConsumerWidget {
  const _BackupTile({required this.backup, required this.actions});

  final BackupFileInfo backup;
  final BackupActionsState actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRestoring = actions.restoringPath == backup.file.path;
    final isDeleting = actions.deletingPath == backup.file.path;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentBrown.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final info = _BackupInfo(backup: backup);
          final buttons = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: actions.isBusy
                    ? null
                    : () => _confirmRestore(context, ref, backup),
                icon: isRestoring
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore_rounded),
                label: Text(isRestoring ? 'جاري الاستعادة' : 'استعادة'),
              ),
              IconButton.filledTonal(
                onPressed: actions.isBusy
                    ? null
                    : () => _confirmDelete(context, ref, backup),
                icon: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                tooltip: 'حذف النسخة',
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [info, const SizedBox(height: 12), buttons],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              buttons,
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmRestore(
    BuildContext context,
    WidgetRef ref,
    BackupFileInfo backup,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('استعادة نسخة احتياطية'),
        content: Text(
          'سيتم استبدال البيانات الحالية ببيانات النسخة:\n${backup.name}\n\nلا يمكن التراجع عن هذه العملية إلا إذا كان لديك نسخة احتياطية أخرى.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(backupActionsProvider.notifier).restoreBackup(backup.file);
      _invalidateAfterRestore(ref);
      if (!context.mounted) return;
      _showMessage(context, 'تمت استعادة النسخة الاحتياطية بنجاح');
      context.go(AppRoutes.welcome);
    } on BackupException catch (error) {
      if (context.mounted) _showMessage(context, error.message, isError: true);
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'تعذر استعادة النسخة الاحتياطية', isError: true);
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BackupFileInfo backup,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('حذف نسخة احتياطية'),
        content: Text('هل تريد حذف النسخة ${backup.name}؟'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(backupActionsProvider.notifier).deleteBackup(backup.file);
      if (context.mounted) _showMessage(context, 'تم حذف النسخة الاحتياطية');
    } on BackupException catch (error) {
      if (context.mounted) _showMessage(context, error.message, isError: true);
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'تعذر حذف النسخة الاحتياطية', isError: true);
      }
    }
  }
}

class _BackupInfo extends StatelessWidget {
  const _BackupInfo({required this.backup});

  final BackupFileInfo backup;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.storage_rounded, color: AppColors.primaryGold),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                backup.name,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '${AppFormatters.dateTime(backup.modifiedAt)}  |  ${_formatBytes(backup.sizeBytes)}',
                style: AppTextStyles.muted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.item});

  final _StatusItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentBrown.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(item.icon, color: AppColors.primaryGold),
              const SizedBox(width: 8),
              Expanded(child: Text(item.label, style: AppTextStyles.muted)),
            ],
          ),
          Text(
            item.value,
            style: Theme.of(context).textTheme.bodyLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatusItem {
  const _StatusItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.title, this.trailing});

  final Widget child;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentBrown.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  )
                else
                  const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppColors.primaryGold),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.muted,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

void _invalidateAfterRestore(WidgetRef ref) {
  ref.invalidate(welcomeDashboardProvider);
  ref.invalidate(ordersHistoryProvider);
  ref.invalidate(reportsDashboardProvider);
  ref.invalidate(adminSettingsProvider);
  ref.invalidate(adminPinProvider);
  ref.invalidate(adminCategoriesProvider);
  ref.invalidate(adminMenuItemsProvider);
  ref.invalidate(posCategoriesProvider);
  ref.invalidate(posMenuItemsProvider);
  ref.invalidate(posVatSettingsProvider);
  ref.invalidate(backupListProvider);
}

void _showMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, textDirection: TextDirection.rtl),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}
