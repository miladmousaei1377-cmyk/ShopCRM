import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routeها، فایل‌ها و وابستگی‌های prediction حذف شده‌اند', () async {
    final forbiddenFiles = [
      'lib/presentation/screens/prediction/prediction_screen.dart',
      'lib/presentation/providers/prediction_provider.dart',
      'lib/services/prediction_service.dart',
      'lib/data/local/daos/prediction_dao.dart',
      'backend/routers/prediction.py',
      'backend/services/prediction_service.py',
      'backend/services/ai_service.py',
    ];
    for (final path in forbiddenFiles) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
    final app = await File('lib/app.dart').readAsString();
    final requirements = await File('backend/requirements.txt').readAsString();
    expect(app, isNot(contains("'/prediction'")));
    for (final dependency in ['prophet', 'anthropic', 'apscheduler']) {
      expect(requirements.toLowerCase(), isNot(contains(dependency)));
    }
  });
}
