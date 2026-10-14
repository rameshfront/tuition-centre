import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class StorageBackupService {
  /// Export complete local database to JSON file and share/save it
  static Future<String?> exportBackup() async {
    try {
      final jsonString = await DBHelper.instance.exportAllDataAsJson();
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFilePath = '${tempDir.path}/sangeetha_tuition_backup_$timestamp.json';

      final file = File(backupFilePath);
      await file.writeAsString(jsonString);

      // Share via Android share sheet
      await Share.shareXFiles(
        [XFile(backupFilePath)],
        subject: 'Sangeetha Tuition Centre DB Backup - $timestamp',
        text: 'Backup data file for Sangeetha Tuition Centre application.',
      );

      return backupFilePath;
    } catch (e) {
      return null;
    }
  }

  /// Import database from a JSON file string
  static Future<bool> restoreBackupFromFile(String fileContent) async {
    try {
      return await DBHelper.instance.importAllDataFromJson(fileContent);
    } catch (e) {
      return false;
    }
  }

  /// Calculate app cache size in bytes
  static Future<int> getCacheSizeInBytes() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (!tempDir.existsSync()) return 0;

      int totalSize = 0;
      await for (final file in tempDir.list(recursive: true, followLinks: false)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return totalSize;
    } catch (_) {
      return 0;
    }
  }

  /// Format bytes to human readable format (KB, MB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Clear all temporary files, cached PDFs, and logs
  static Future<bool> clearAppCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final entities = tempDir.listSync(recursive: true);
        for (final entity in entities) {
          try {
            if (entity is File) {
              await entity.delete();
            }
          } catch (_) {}
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
