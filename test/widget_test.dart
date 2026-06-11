/// تست‌های پایه برای اطمینان از اجرا شدن برنامه
/// تست‌های جامع‌تر در test/utils/ و test/models/ قرار دارند
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_crm/core/utils/currency_formatter.dart';
import 'package:shop_crm/core/utils/date_converter.dart';

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
}
