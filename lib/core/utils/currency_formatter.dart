import 'package:intl/intl.dart';

/// ابزار فرمت‌بندی ارز و اعداد فارسی
/// تمام نمایش قیمت در برنامه از این کلاس عبور می‌کند
class CurrencyFormatter {
  CurrencyFormatter._();

  // فرمت‌کننده با جداکننده هزار (انگلیسی برای محاسبه، فارسی برای نمایش)
  static final _formatterEn = NumberFormat('#,###');

  /// فرمت کامل مبلغ با جداکننده هزار و واحد تومان
  /// مثال: ۱,۲۳۴,۵۶۷ تومان
  static String format(num amount, {bool showUnit = true}) {
    if (amount == 0) return showUnit ? '۰ تومان' : '۰';
    final formatted = _toFarsiNumber(_formatterEn.format(amount.round()));
    return showUnit ? '$formatted تومان' : formatted;
  }

  /// فرمت عدد بدون واحد (فقط با جداکننده هزار)
  static String formatNumber(num amount) => format(amount, showUnit: false);

  /// تبدیل اعداد لاتین به فارسی
  /// مثال: 1234 → ۱۲۳۴
  static String _toFarsiNumber(String input) {
    const english = ['0','1','2','3','4','5','6','7','8','9'];
    const farsi   = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
    String result = input;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], farsi[i]);
    }
    return result;
  }

  /// تبدیل اعداد فارسی به لاتین (برای محاسبات)
  /// مثال: ۱۲۳۴ → 1234
  static String toEnglishNumber(String input) {
    const farsi   = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
    const english = ['0','1','2','3','4','5','6','7','8','9'];
    String result = input;
    for (int i = 0; i < farsi.length; i++) {
      result = result.replaceAll(farsi[i], english[i]);
    }
    return result;
  }

  /// پارس کردن رشته مبلغ فارسی به عدد double
  /// مثال: "۱,۲۳۴,۰۰۰ تومان" → 1234000.0
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

  /// نمایش درصد به فارسی
  /// مثال: 15.5 → ۱۵.۵٪
  static String formatPercent(double percent) {
    final val = percent.truncateToDouble() == percent
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
    return '${_toFarsiNumber(val)}٪';
  }

  /// نمایش تعداد با واحد عدد
  /// مثال: 12 → ۱۲ عدد
  static String formatQuantity(int qty) {
    return '${_toFarsiNumber(qty.toString())} عدد';
  }
}
