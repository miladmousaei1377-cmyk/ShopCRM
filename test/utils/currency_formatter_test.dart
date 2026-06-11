import 'package:flutter_test/flutter_test.dart';
import 'package:shop_crm/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    group('format', () {
      test('صفر با واحد نمایش می‌دهد', () {
        expect(CurrencyFormatter.format(0), '۰ تومان');
      });

      test('عدد مثبت را با واحد فرمت می‌کند', () {
        expect(CurrencyFormatter.format(1000), '۱,۰۰۰ تومان');
      });

      test('عدد بزرگ را با جداکننده هزار نشان می‌دهد', () {
        expect(CurrencyFormatter.format(1234567), '۱,۲۳۴,۵۶۷ تومان');
      });

      test('بدون واحد فقط عدد را برمی‌گرداند', () {
        expect(CurrencyFormatter.format(5000, showUnit: false), '۵,۰۰۰');
      });

      test('اعشار را گرد می‌کند', () {
        expect(CurrencyFormatter.format(999.7), '۱,۰۰۰ تومان');
      });
    });

    group('formatNumber', () {
      test('عدد را بدون واحد برمی‌گرداند', () {
        expect(CurrencyFormatter.formatNumber(2500), '۲,۵۰۰');
      });
    });

    group('parse', () {
      test('رشته فارسی را به double تبدیل می‌کند', () {
        expect(CurrencyFormatter.parse('۱,۰۰۰ تومان'), 1000.0);
      });

      test('عدد ساده را parse می‌کند', () {
        expect(CurrencyFormatter.parse('5000'), 5000.0);
      });

      test('رشته نامعتبر null برمی‌گرداند', () {
        expect(CurrencyFormatter.parse('abc'), isNull);
      });
    });

    group('formatPercent', () {
      test('عدد صحیح را بدون اعشار نمایش می‌دهد', () {
        expect(CurrencyFormatter.formatPercent(15.0), '۱۵٪');
      });

      test('عدد اعشاری را با یک رقم اعشار نشان می‌دهد', () {
        expect(CurrencyFormatter.formatPercent(12.5), '۱۲.۵٪');
      });
    });

    group('formatQuantity', () {
      test('تعداد را با واحد عدد نمایش می‌دهد', () {
        expect(CurrencyFormatter.formatQuantity(7), '۷ عدد');
      });
    });

    group('toEnglishNumber', () {
      test('اعداد فارسی را به انگلیسی تبدیل می‌کند', () {
        expect(CurrencyFormatter.toEnglishNumber('۱۲۳۴'), '1234');
      });

      test('رشته مخلوط را درست تبدیل می‌کند', () {
        expect(CurrencyFormatter.toEnglishNumber('۱,۲۳۴'), '1,234');
      });
    });
  });
}
