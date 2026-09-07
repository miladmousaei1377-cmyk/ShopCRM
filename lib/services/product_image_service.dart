import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'app_paths.dart';
import 'log_service.dart';

class ProductImageService {
  ProductImageService._();

  static Future<String> importImage(XFile source) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('فایل تصویر معتبر نیست');
    final resized = decoded.width > 1280 || decoded.height > 1280
        ? img.copyResize(decoded,
            width: decoded.width >= decoded.height ? 1280 : null,
            height: decoded.height > decoded.width ? 1280 : null)
        : decoded;
    final name = '${const Uuid().v4()}.jpg';
    final directory = await AppPaths.productImagesDirectory();
    final target = File(p.join(directory.path, name));
    await target.writeAsBytes(img.encodeJpg(resized, quality: 85), flush: true);
    return name;
  }

  static Future<File?> resolve(String? relativePath) async {
    if (relativePath == null ||
        relativePath.isEmpty ||
        p.isAbsolute(relativePath)) {
      return null;
    }
    final directory = await AppPaths.productImagesDirectory();
    final file = File(p.join(directory.path, p.basename(relativePath)));
    return await file.exists() ? file : null;
  }

  static Future<void> delete(String? relativePath) async {
    try {
      final file = await resolve(relativePath);
      if (file != null) await file.delete();
    } catch (error, stack) {
      await LogService.error('حذف تصویر محصول ناموفق بود', error, stack);
    }
  }
}
