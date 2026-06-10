import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _formatter = NumberFormat('#,###', 'fa');
  static final _formatterEn = NumberFormat('#,###');

  /// فرمت مبلغ با جداکننده هزار و واحد تومان
  /// مثال: ۱,۲۳۴,۰۰۰ تومان
  static String format(num amount, {bool showUnit = true}) {
    if (amount == 0) return showUnit ? '۰ تومان' : '۰';
    final formatted = _toFarsiNumber(_formatterEn.format(amount.round()));
    return showUnit ? '$formatted تومان' : formatted;
  }

  /// فرمت بدون واحد
  static String formatNumber(num amount) => format(amount, showUnit: false);

  /// تبدیل به فارسی
  static String _toFarsiNumber(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const farsi = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    String result = input;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], farsi[i]);
    }
    return result;
  }

  /// تبدیل اعداد فارسی به انگلیسی
  static String toEnglishNumber(String input) {
    const farsi = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < farsi.length; i++) {
      result = result.replaceAll(farsi[i], english[i]);
    }
    return result;
  }

  /// پارس کردن رشته به عدد
  static double? parse(String input) {
    try {
      final cleaned = toEnglishNumber(input)
          .replaceAll(',', '')
          .replaceAll(' تومان', '')
          .trim();
      return double.parse(cleaned);
    } catch (_) {
      return null;
    }
  }

  /// نمایش درصد
  static String formatPercent(double percent) {
    return '${_toFarsiNumber(percent.toStringAsFixed(percent.truncateToDouble() == percent ? 0 : 1))}٪';
  }

  /// نمایش تعداد با واحد
  static String formatQuantity(int qty) {
    return '${_toFarsiNumber(qty.toString())} عدد';
  }
}
