import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../../config/constants.dart';

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  static const String _keyAutoBackup = 'auto_backup';
  static const String _keyLastBackup = 'last_backup_time';

  // Default backup directory name
  static const String _backupDirName = 'LaundryBackups';

  Future<void> performAutoBackupIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final isAutoBackup = prefs.getBool(_keyAutoBackup) ?? false;

    if (!isAutoBackup) return;

    final lastBackupStr = prefs.getString(_keyLastBackup);
    final now = DateTime.now();

    if (lastBackupStr != null) {
      final lastBackup = DateTime.parse(lastBackupStr);
      // Auto backup once a day
      if (now.difference(lastBackup).inHours < 24) {
        return;
      }
    }

    // Perform backup
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final backupDir = Directory(
        join(documentsDirectory.path, _backupDirName),
      );
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = 'laundry_backup_$timestamp.db';
      final backupPath = join(backupDir.path, fileName);

      await backupDatabase(backupPath);

      // Update last backup time
      await prefs.setString(_keyLastBackup, now.toIso8601String());
      debugPrint('Auto backup completed: $backupPath');

      // Cleanup old backups (keep last 7 days)
      await _cleanupOldBackups(backupDir);
    } catch (e) {
      debugPrint('Auto backup failed: $e');
    }
  }

  Future<void> backupDatabase(String destinationPath) async {
    // Close DB to ensure WAL is flushed and file is not locked on Windows
    await DatabaseHelper.instance.close();

    final dbPath = await _getDbPath();
    final sourceFile = File(dbPath);
    await sourceFile.copy(destinationPath);

    // Also copy WAL and SHM files if they exist
    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');
    if (await walFile.exists()) {
      await walFile.copy('$destinationPath-wal');
    }
    if (await shmFile.exists()) {
      await shmFile.copy('$destinationPath-shm');
    }

    // Re-open DB connection
    await DatabaseHelper.instance.database;
  }

  Future<void> restoreDatabase(String sourcePath) async {
    final sourceFile = File(sourcePath);

    // Validate that the file is a valid SQLite database
    if (!await sourceFile.exists()) {
      throw Exception('File backup không tồn tại');
    }

    final bytes = await sourceFile.openRead(0, 16).first;
    final header = String.fromCharCodes(bytes.take(15));
    if (!header.startsWith('SQLite format')) {
      throw Exception('File không phải là database SQLite hợp lệ');
    }

    // Use DatabaseHelper's restore which handles close → copy → re-init
    await DatabaseHelper.instance.restoreDatabase(sourcePath);
  }

  Future<String> _getDbPath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbFolder = join(documentsDirectory.path, 'LaundryManagement');
    return join(dbFolder, AppConstants.dbName);
  }

  Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final List<FileSystemEntity> files = await backupDir.list().toList();
      final now = DateTime.now();

      for (final file in files) {
        if (file is File && basename(file.path).startsWith('laundry_backup_')) {
          final stat = await file.stat();
          if (now.difference(stat.modified).inDays > 7) {
            await file.delete();
            debugPrint('Deleted old backup: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('Cleanup failed: $e');
    }
  }
}
