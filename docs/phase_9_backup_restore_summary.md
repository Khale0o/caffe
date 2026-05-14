# Phase 9: Backup and Restore System

## What was implemented

- Replaced the settings placeholder with a production local backup and restore screen.
- Added full SQLite database backup generation.
- Added restore from existing local backups.
- Added backup listing with file name, size, and modified date.
- Added delete and refresh actions for backup files.
- Added validation before restore to reject invalid or corrupted files.
- Added provider invalidation after restore so app data reloads cleanly.

## Files created

- `lib/features/backup/application/backup_service.dart`
- `lib/features/backup/application/backup_providers.dart`
- `lib/features/backup/presentation/backup_screen.dart`
- `test/backup_restore_test.dart`
- `docs/phase_9_backup_restore_summary.md`

## Files modified

- `lib/core/database/app_database.dart`
- `lib/core/router/app_router.dart`

## Backup flow

1. User opens `النسخ الاحتياطي` from the settings route.
2. User taps `إنشاء نسخة احتياطية`.
3. The app initializes the current database, resolves the SQLite file path, closes the database safely, copies it into the backups folder, then reopens the database.
4. The copied file is validated as a readable app SQLite database.
5. The backup list refreshes and the latest backup metadata is shown.

Backup file names use timestamped names:

- `cafe_backup_yyyy_MM_dd_HH_mm_ss.db`

## Restore flow

1. User selects a backup from the local backup list.
2. The app shows a confirmation dialog explaining that current data will be replaced.
3. The backup file is validated before restore.
4. The current database is closed.
5. A temporary safety copy of the current database is created.
6. The backup file replaces the active SQLite database.
7. The database is reopened.
8. Key app providers are invalidated and the app returns to the welcome screen.
9. If restore fails, the safety copy is restored and the database is reopened.

## Safety protections

- Prevents duplicate backup creation taps.
- Prevents overlapping restore operations.
- Prevents delete while backup or restore is active.
- Validates backup file existence.
- Validates `.db` extension.
- Rejects empty files.
- Runs SQLite `PRAGMA integrity_check`.
- Verifies required Cafe POS tables exist.
- Uses Arabic user-facing error messages.
- Restores the previous database from a safety copy if replacement fails.

## Storage behavior

- Backups are stored locally in a dedicated `cafe_pos_backups` folder under the app documents directory.
- The folder is created automatically if missing.
- Multiple backup files are supported.
- Backup list is sorted newest first.
- Backup size and modified date are displayed.

## Validation behavior

The validation checks:

- File exists.
- File has `.db` extension.
- File size is greater than zero.
- SQLite can open it read-only.
- `PRAGMA integrity_check` returns `ok`.
- Required tables exist:
  - `customers`
  - `categories`
  - `menu_items`
  - `orders`
  - `order_items`
  - `settings`

## Manual testing checklist

- Open `النسخ الاحتياطي` from the settings button.
- Create a backup and confirm it appears in the list.
- Confirm latest backup name, date, and size are shown.
- Create multiple backups and confirm newest appears first.
- Delete a backup after confirmation.
- Save new customer/order data, restore an older backup, and confirm the data returns to the backup state.
- Try restoring after rapid repeated taps and confirm only one restore runs.
- Try creating backups with rapid repeated taps and confirm only one backup runs.
- Test on Windows desktop with resizing.
- Test on Android phone/tablet for scrolling, dialogs, and safe-area behavior.

## Known limitations

- Cloud sync is not implemented.
- Scheduled automatic backups are not implemented.
- External file import/export is not implemented yet; this phase manages the app's local backup folder.
- Backup files are raw SQLite database files and should be handled carefully by users.

## Next recommended phase

Add optional manual export/import locations and then scheduled local backup settings. Cloud backup can be considered later as a separate sync phase.
