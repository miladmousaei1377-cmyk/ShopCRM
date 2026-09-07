import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  AppPaths._();

  static Future<Directory> dataDirectory() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'ShopCRM'));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> productImagesDirectory() async {
    final root = await dataDirectory();
    final dir = Directory(p.join(root.path, 'product_images'));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> backupsDirectory() async {
    final root = await dataDirectory();
    final dir = Directory(p.join(root.path, 'backups'));
    await dir.create(recursive: true);
    return dir;
  }
}
