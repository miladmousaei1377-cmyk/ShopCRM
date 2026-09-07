import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/local/database.dart';
import 'app_paths.dart';
import 'log_service.dart';

class BackupService {
  BackupService._();

  static const _lastBackupKey = 'last_auto_backup';
  static const _autoEnabledKey = 'auto_backup_enabled';
  static const _retainedBackups = 10;
  static AppDatabase? _database;

  static void configure(AppDatabase database) => _database = database;

  static Future<File?> createBackup({bool share = false}) async {
    final db = _database;
    if (db == null) throw StateError('BackupService پیکربندی نشده است');
    File? snapshot;
    try {
      final backupDir = await AppPaths.backupsDirectory();
      final now = DateTime.now();
      final stamp = '${now.year}${_two(now.month)}${_two(now.day)}_'
          '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}_'
          '${now.millisecond.toString().padLeft(3, '0')}';
      snapshot = File(p.join(backupDir.path, 'shopcrm_$stamp.sqlite'));

      await db.customStatement('PRAGMA wal_checkpoint(FULL)');
      final escaped = snapshot.path.replaceAll("'", "''");
      await db.customStatement("VACUUM INTO '$escaped'");

      final zipFile = File(p.join(backupDir.path, 'shopcrm_$stamp.zip'));
      final encoder = ZipFileEncoder()..create(zipFile.path);
      encoder.addFile(snapshot, 'database/${AppDatabase.databaseFileName}');
      final images = await AppPaths.productImagesDirectory();
      await for (final entity in images.list()) {
        if (entity is File) {
          encoder.addFile(
              entity, p.join('product_images', p.basename(entity.path)));
        }
      }
      encoder.close();
      await snapshot.delete();
      snapshot = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, now.toIso8601String());
      await _applyRetention(backupDir);

      if (share) {
        await SharePlus.instance.share(ShareParams(
          files: [XFile(zipFile.path)],
          subject: 'پشتیبان فروشگاه هوشمند',
          text: 'پشتیبان داده‌ها و تصاویر فروشگاه - $stamp',
        ));
      }
      return zipFile;
    } catch (error, stack) {
      await LogService.error('ایجاد پشتیبان ناموفق بود', error, stack);
      if (snapshot != null && await snapshot.exists()) await snapshot.delete();
      return null;
    }
  }

  static Future<void> _applyRetention(Directory directory) async {
    final backups = await directory
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.zip'))
        .cast<File>()
        .toList();
    backups
        .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final old in backups.skip(_retainedBackups)) {
      await old.delete();
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static Future<bool> isAutoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoEnabledKey) ?? true;
  }

  static Future<void> setAutoEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoEnabledKey, value);
  }

  static Future<String?> getLastBackupLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_lastBackupKey);
    if (str == null) return 'هرگز';
    final dt = DateTime.tryParse(str);
    if (dt == null) return 'نامشخص';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'همین الان';
    if (diff.inHours < 1) return '${diff.inMinutes} دقیقه پیش';
    if (diff.inDays < 1) return '${diff.inHours} ساعت پیش';
    return '${diff.inDays} روز پیش';
  }

  static Future<void> autoBackupIfNeeded() async {
    if (!await isAutoEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_lastBackupKey);
    if (str != null) {
      final last = DateTime.tryParse(str);
      if (last != null && DateTime.now().difference(last).inMinutes < 30) {
        return;
      }
    }
    await createBackup();
  }
}
