import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  BackupService._();

  static const _lastBackupKey = 'last_auto_backup';
  static const _autoEnabledKey = 'auto_backup_enabled';
  static const _dbName = 'shop_crm_db.db';

  static Future<File?> _findDbFile() async {
    final candidates = <Future<Directory>>[
      getApplicationDocumentsDirectory(),
      getApplicationSupportDirectory(),
    ];
    for (final dirFuture in candidates) {
      try {
        final dir = await dirFuture;
        // Direct path
        var f = File('${dir.path}/$_dbName');
        if (await f.exists()) return f;
        // Android databases dir (sibling of files dir)
        if (Platform.isAndroid) {
          f = File('${dir.parent.path}/databases/$_dbName');
          if (await f.exists()) return f;
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<File?> createBackup({bool share = false}) async {
    try {
      final dbFile = await _findDbFile();
      if (dbFile == null) return null;

      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      if (!await backupDir.exists()) await backupDir.create(recursive: true);

      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
          '_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final backupFile = File('${backupDir.path}/shopcrm_$dateStr.db');
      await dbFile.copy(backupFile.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, now.toIso8601String());

      if (share) {
        await SharePlus.instance.share(ShareParams(
          files: [XFile(backupFile.path)],
          subject: 'بکاپ فروشگاه هوشمند',
          text: 'بکاپ داده‌های فروشگاه هوشمند - $dateStr',
        ));
      }

      return backupFile;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isAutoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoEnabledKey) ?? false;
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
      if (last != null && DateTime.now().difference(last).inDays < 7) return;
    }
    await createBackup();
  }
}
