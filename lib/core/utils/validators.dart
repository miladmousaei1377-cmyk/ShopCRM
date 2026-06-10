/// اعتبارسنجی فیلدهای ورودی
/// همه توابع یا null (معتبر) یا پیام خطای فارسی برمی‌گردانند
class Validators {
  Validators._();

  /// فیلد اجباری - نباید خالی باشد
  static String? required(String? value, {String fieldName = 'این فیلد'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName الزامی است';
    }
    return null;
  }

  /// شماره موبایل ایران (۱۱ رقم با ۰)
  static String? phone(String? value) {
    if (value == null || value.isEmpty) return 'شماره تماس الزامی است';
    final cleaned = _toEnglish(value.replaceAll(' ', '').replaceAll('-', ''));
    if (!RegExp(r'^0[0-9]{10}$').hasMatch(cleaned)) {
      return 'شماره تماس معتبر نیست (مثال: ۰۹۱۲۳۴۵۶۷۸۹)';
    }
    return null;
  }

  /// اعتبارسنجی قیمت (عدد مثبت)
  static String? price(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'قیمت الزامی است' : null;
    }
    final cleaned = _toEnglish(value.replaceAll(',', '').replaceAll(' تومان', ''));
    final parsed = double.tryParse(cleaned);
    if (parsed == null || parsed < 0) return 'قیمت معتبر نیست';
    return null;
  }

  /// اعتبارسنجی تعداد (عدد صحیح غیرمنفی)
  static String? quantity(String? value) {
    if (value == null || value.trim().isEmpty) return 'تعداد الزامی است';
    final parsed = int.tryParse(_toEnglish(value));
    if (parsed == null || parsed < 0) return 'تعداد معتبر نیست';
    return null;
  }

  /// بارکد اختیاری (۴ تا ۲۰ کاراکتر)
  static String? barcode(String? value) {
    if (value == null || value.trim().isEmpty) return null; // بارکد اجباری نیست
    final cleaned = _toEnglish(value.trim());
    if (cleaned.length < 4 || cleaned.length > 20) {
      return 'بارکد باید بین ۴ تا ۲۰ کاراکتر باشد';
    }
    return null;
  }

  /// نام کاربری (حداقل ۳ کاراکتر)
  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'نام کاربری الزامی است';
    if (value.length < 3) return 'نام کاربری حداقل ۳ کاراکتر باشد';
    return null;
  }

  /// رمز عبور (حداقل ۴ کاراکتر)
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'رمز عبور الزامی است';
    if (value.length < 4) return 'رمز عبور حداقل ۴ کاراکتر باشد';
    return null;
  }

  /// آدرس IP معتبر (مثل ۱۹۲.۱۶۸.۱.۱)
  static String? ipAddress(String? value) {
    if (value == null || value.trim().isEmpty) return 'آدرس IP الزامی است';
    final parts = _toEnglish(value.trim()).split('.');
    if (parts.length != 4) return 'آدرس IP معتبر نیست';
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return 'آدرس IP معتبر نیست';
    }
    return null;
  }

  /// پورت شبکه (۱ تا ۶۵۵۳۵)
  static String? port(String? value) {
    if (value == null || value.trim().isEmpty) return 'پورت الزامی است';
    final num = int.tryParse(_toEnglish(value.trim()));
    if (num == null || num < 1 || num > 65535) {
      return 'پورت باید بین ۱ تا ۶۵۵۳۵ باشد';
    }
    return null;
  }

  /// درصد تخفیف (۰ تا ۱۰۰)
  static String? discountPercent(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(_toEnglish(value));
    if (parsed == null || parsed < 0 || parsed > 100) {
      return 'درصد تخفیف باید بین ۰ تا ۱۰۰ باشد';
    }
    return null;
  }

  /// تبدیل داخلی: فارسی → لاتین برای مقایسه
  static String _toEnglish(String input) {
    const f = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
    const e = ['0','1','2','3','4','5','6','7','8','9'];
    String result = input;
    for (int i = 0; i < f.length; i++) {
      result = result.replaceAll(f[i], e[i]);
    }
    return result;
  }
}
