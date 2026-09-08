/// تست‌های پایه برای اطمینان از اجرا شدن برنامه
/// تست‌های جامع‌تر در test/utils/ و test/models/ قرار دارند
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shop_crm/core/utils/currency_formatter.dart';
import 'package:shop_crm/core/utils/date_converter.dart';
import 'package:shop_crm/presentation/widgets/common/confirm_dialog.dart';
import 'package:shop_crm/app.dart';

void main() {
  test('CurrencyFormatter: فرمت پایه کار می‌کند', () {
    expect(CurrencyFormatter.format(0), '۰ تومان');
    expect(CurrencyFormatter.format(1000), '۱,۰۰۰ تومان');
  });

  test('DateConverter: تبدیل اعداد انگلیسی به فارسی', () {
    final result = DateConverter.toEnglish('۱۴۰۳');
    expect(result, '1403');
  });

  test('DateConverter: تبدیل تاریخ میلادی به شمسی', () {
    final date = DateTime(2024, 3, 20);
    final shamsi = DateConverter.toShamsi(date);
    expect(shamsi, isNotEmpty);
    expect(shamsi.contains('/'), isTrue);
  });

  testWidgets('ConfirmDialog موجود در عرض دسکتاپ و موبایل بدون overflow است',
      (tester) async {
    for (final size in [const Size(375, 700), const Size(1100, 700)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ConfirmDialog(
            title: 'تأیید حذف',
            message: 'آیا از حذف این مورد مطمئن هستید؟',
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('تأیید حذف'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('بستن پنجره قبل از خروج تأیید می‌گیرد', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showExitConfirmation(context),
          child: const Text('خروج'),
        ),
      ),
    ));
    await tester.tap(find.text('خروج'));
    await tester.pumpAndSettle();
    expect(find.text('آیا می‌خواهید از برنامه خارج شوید؟'), findsOneWidget);
    await tester.tap(find.text('بازگشت'));
    await tester.pumpAndSettle();
    expect(find.text('آیا می‌خواهید از برنامه خارج شوید؟'), findsNothing);
  });
}
