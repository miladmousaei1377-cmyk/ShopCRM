import 'dart:developer' as developer;
import 'dart:io';
import 'package:path/path.dart' as p;
import 'app_paths.dart';

class LogService {
  LogService._();

  static Future<void> error(
      String message, Object error, StackTrace stack) async {
    developer.log(message, error: error, stackTrace: stack, name: 'ShopCRM');
    try {
      final root = await AppPaths.dataDirectory();
      final file = File(p.join(root.path, 'shopcrm.log'));
      await file.writeAsString(
        '${DateTime.now().toIso8601String()} $message\n$error\n$stack\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      stderr.writeln('$message: $error');
    }
  }
}
