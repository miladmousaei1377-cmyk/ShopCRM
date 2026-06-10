import 'package:flutter/material.dart';

/// تعریف تمام رنگ‌های برنامه در یک جا
/// تغییر رنگ‌بندی کل اپ فقط از این فایل انجام می‌شود
class AppColors {
  AppColors._();

  // ─── رنگ‌های اصلی (Primary) ─────────────────────────────────
  static const Color primary      = Color(0xFF1565C0); // آبی اصلی
  static const Color primaryLight = Color(0xFF1E88E5); // آبی روشن‌تر
  static const Color primaryDark  = Color(0xFF0D47A1); // آبی تیره‌تر

  // ─── رنگ‌های ثانویه (Secondary) ─────────────────────────────
  static const Color secondary      = Color(0xFF00897B); // سبز فیروزه‌ای
  static const Color secondaryLight = Color(0xFF26A69A);

  // ─── رنگ‌های پس‌زمینه ────────────────────────────────────────
  static const Color background    = Color(0xFFF5F6FA); // خاکستری خیلی روشن
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color cardBackground= Color(0xFFFFFFFF);

  // ─── رنگ‌های متن ─────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1A1A2E); // متن اصلی (تیره)
  static const Color textSecondary = Color(0xFF6B7280); // متن فرعی (خاکستری)
  static const Color textHint      = Color(0xFF9CA3AF); // راهنما و placeholder

  // ─── رنگ‌های وضعیت ───────────────────────────────────────────
  static const Color success      = Color(0xFF2E7D32); // موفق (سبز)
  static const Color successLight = Color(0xFFE8F5E9); // پس‌زمینه موفق
  static const Color warning      = Color(0xFFE65100); // هشدار (نارنجی)
  static const Color warningLight = Color(0xFFFFF3E0); // پس‌زمینه هشدار
  static const Color error        = Color(0xFFC62828); // خطا (قرمز)
  static const Color errorLight   = Color(0xFFFFEBEE); // پس‌زمینه خطا
  static const Color info         = Color(0xFF1565C0); // اطلاعات (آبی)
  static const Color infoLight    = Color(0xFFE3F2FD); // پس‌زمینه اطلاعات

  // ─── جداکننده و حاشیه ────────────────────────────────────────
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border  = Color(0xFFD1D5DB);

  // ─── رنگ کارت‌های داشبورد ────────────────────────────────────
  static const Color cardSales     = Color(0xFF1565C0); // فروش امروز
  static const Color cardInventory = Color(0xFF2E7D32); // موجودی کل
  static const Color cardAlert     = Color(0xFFE65100); // هشدار کمبود
  static const Color cardDebt      = Color(0xFF6A1B9A); // بدهکاران

  // ─── رنگ‌های نمودار ──────────────────────────────────────────
  static const List<Color> chartColors = [
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFE65100),
    Color(0xFF6A1B9A),
    Color(0xFF00838F),
  ];

  // ─── رنگ روش‌های پرداخت ──────────────────────────────────────
  static const Color cashColor   = Color(0xFF2E7D32); // نقد = سبز
  static const Color cardColor   = Color(0xFF1565C0); // کارت = آبی
  static const Color creditColor = Color(0xFFE65100); // نسیه = نارنجی
}
