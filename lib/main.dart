import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/notification_service.dart';

/// نقطه شروع برنامه
void main() async {
  // اطمینان از آماده بودن Flutter binding قبل از هر کار async
  WidgetsFlutterBinding.ensureInitialized();

  // پشتیبانی از هر دو جهت نمایش (portrait + landscape)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // شفافیت نوار وضعیت اندروید
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // راه‌اندازی سرویس اعلان‌ها در پس‌زمینه — بدون block کردن startup
  NotificationService.init().catchError((_) {});

  // ProviderScope: ریشه Riverpod — همه Provider‌ها داخل این زنده می‌مانند
  runApp(
    const ProviderScope(
      child: ShopCrmApp(),
    ),
  );
}
