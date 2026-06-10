import 'package:shamsi_date/shamsi_date.dart';

class DateConverter {
  DateConverter._();

  static const List<String> _farsiMonths = [
    'فروردین', 'اردیبهشت', 'خرداد',
    'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر',
    'دی', 'بهمن', 'اسفند',
  ];

  static const List<String> _farsiWeekDays = [
    'شنبه', 'یک‌شنبه', 'دوشنبه',
    'سه‌شنبه', 'چهارشنبه', 'پنج‌شنبه', 'جمعه',
  ];

  /// تبدیل DateTime به تاریخ شمسی (۱۴۰۳/۰۱/۱۵)
  static String toShamsi(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    final y = _toFarsi(jalali.year.toString());
    final m = _toFarsi(jalali.month.toString().padLeft(2, '0'));
    final d = _toFarsi(jalali.day.toString().padLeft(2, '0'));
    return '$y/$m/$d';
  }

  /// تاریخ کامل با نام ماه (۱۵ فروردین ۱۴۰۳)
  static String toShamsiLong(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    final day = _toFarsi(jalali.day.toString());
    final month = _farsiMonths[jalali.month - 1];
    final year = _toFarsi(jalali.year.toString());
    return '$day $month $year';
  }

  /// تاریخ + ساعت (۱۴۰۳/۰۱/۱۵ - ۱۴:۳۰)
  static String toShamsiWithTime(DateTime date) {
    final dateStr = toShamsi(date);
    final hour = _toFarsi(date.hour.toString().padLeft(2, '0'));
    final minute = _toFarsi(date.minute.toString().padLeft(2, '0'));
    return '$dateStr - $hour:$minute';
  }

  /// فقط ساعت
  static String toTime(DateTime date) {
    final hour = _toFarsi(date.hour.toString().padLeft(2, '0'));
    final minute = _toFarsi(date.minute.toString().padLeft(2, '0'));
    return '$hour:$minute';
  }

  /// نام روز هفته
  static String weekDayName(DateTime date) {
    // شنبه = 0 در تقویم ایرانی
    final jalali = Jalali.fromDateTime(date);
    final weekDay = jalali.weekDay - 1; // 0-6
    return _farsiWeekDays[weekDay];
  }

  /// امروز
  static String get today => toShamsi(DateTime.now());

  /// تبدیل string شمسی به DateTime
  static DateTime? fromShamsi(String dateStr) {
    try {
      final parts = dateStr.replaceAll('/', '-').split('-');
      if (parts.length != 3) return null;
      final year = int.parse(toEnglish(parts[0]));
      final month = int.parse(toEnglish(parts[1]));
      final day = int.parse(toEnglish(parts[2]));
      return Jalali(year, month, day).toDateTime();
    } catch (_) {
      return null;
    }
  }

  /// تبدیل عدد به فارسی
  static String _toFarsi(String input) {
    const e = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const f = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    String result = input;
    for (int i = 0; i < e.length; i++) {
      result = result.replaceAll(e[i], f[i]);
    }
    return result;
  }

  /// تبدیل عدد به انگلیسی
  static String toEnglish(String input) {
    const f = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const e = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < f.length; i++) {
      result = result.replaceAll(f[i], e[i]);
    }
    return result;
  }

  /// فاصله زمانی (مثلاً: ۳ ساعت پیش)
  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'لحظاتی پیش';
    if (diff.inMinutes < 60) return '${_toFarsi(diff.inMinutes.toString())} دقیقه پیش';
    if (diff.inHours < 24) return '${_toFarsi(diff.inHours.toString())} ساعت پیش';
    if (diff.inDays < 7) return '${_toFarsi(diff.inDays.toString())} روز پیش';
    return toShamsi(date);
  }
}
