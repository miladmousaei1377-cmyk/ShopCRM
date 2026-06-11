/// سرویس خروجی Excel برای گزارش‌های فروش و فاکتورها
/// از پکیج excel و share_plus استفاده می‌کند
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/utils/date_converter.dart';
import '../core/utils/currency_formatter.dart';
import '../domain/models/invoice.dart';
import '../data/repositories/report_repository.dart';

class ExcelService {
  ExcelService._();

  // ─── خروجی Excel گزارش فروش ────────────────────────────────────────────────

  /// تولید فایل Excel گزارش فروش
  /// شیت ۱: فروش روزانه (تاریخ، مبلغ فروش)
  /// شیت ۲: پرفروش‌ترین محصولات (نام، تعداد، درآمد)
  static Future<void> exportSalesReport(SalesReport report) async {
    // ایجاد کتاب Excel جدید
    final excel = Excel.createExcel();

    // ─── شیت ۱: فروش روزانه ─────────────────────────────────────────────────
    final dailySheet = excel['فروش روزانه'];
    // حذف شیت پیش‌فرض Sheet1
    excel.delete('Sheet1');

    // هدر ستون‌های شیت فروش روزانه
    _addRow(dailySheet, [
      'تاریخ',
      'مبلغ فروش (تومان)',
      'تعداد فاکتور',
    ], isHeader: true);

    // داده‌های روزانه — مرتب‌شده بر اساس تاریخ
    final sortedDailySales = report.dailySales.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedDailySales) {
      // تبدیل تاریخ میلادی به شمسی برای نمایش
      final shamsiDate = _convertDateKey(entry.key);
      _addRow(dailySheet, [
        shamsiDate,
        entry.value.toStringAsFixed(0),
        '', // تعداد فاکتور در این نسخه محاسبه نمی‌شود
      ]);
    }

    // اضافه کردن ردیف جمع کل در انتها
    _addRow(dailySheet, [
      'جمع کل',
      report.totalSales.toStringAsFixed(0),
      report.totalInvoices.toString(),
    ], isHeader: true);

    // ─── شیت ۲: پرفروش‌ترین محصولات ─────────────────────────────────────────
    final topSheet = excel['پرفروش‌ترین محصولات'];

    // هدر ستون‌های شیت محصولات
    _addRow(topSheet, [
      'نام محصول',
      'تعداد فروش',
      'درآمد (تومان)',
    ], isHeader: true);

    // داده‌های پرفروش‌ترین محصولات — از قبل مرتب‌شده
    for (final product in report.topProducts) {
      _addRow(topSheet, [
        product.productName,
        product.totalQuantity.toString(),
        product.totalRevenue.toStringAsFixed(0),
      ]);
    }

    // ذخیره و اشتراک‌گذاری فایل Excel
    await _saveAndShare(excel, 'گزارش_فروش_${_today()}');
  }

  // ─── خروجی Excel لیست فاکتورها ──────────────────────────────────────────────

  /// تولید فایل Excel از لیست فاکتورها
  /// یک ردیف به ازای هر فاکتور: شماره، تاریخ، مشتری، مبلغ، روش پرداخت
  static Future<void> exportInvoices(List<Invoice> invoices) async {
    final excel = Excel.createExcel();

    // شیت فاکتورها
    final sheet = excel['فاکتورها'];
    excel.delete('Sheet1');

    // هدر ستون‌ها
    _addRow(sheet, [
      'شماره فاکتور',
      'تاریخ',
      'نام مشتری',
      'جمع کل (تومان)',
      'تخفیف (تومان)',
      'مالیات (تومان)',
      'مبلغ نهایی (تومان)',
      'روش پرداخت',
      'وضعیت',
    ], isHeader: true);

    // ردیف‌های فاکتورها
    for (final invoice in invoices) {
      _addRow(sheet, [
        invoice.invoiceNumber,
        DateConverter.toShamsi(invoice.createdAt),
        invoice.customerName ?? 'مشتری ناشناس',
        invoice.totalAmount.toStringAsFixed(0),
        invoice.discountAmount.toStringAsFixed(0),
        invoice.taxAmount.toStringAsFixed(0),
        invoice.finalAmount.toStringAsFixed(0),
        invoice.paymentMethod.label,
        invoice.status.label,
      ]);
    }

    // ردیف جمع کل مبلغ نهایی
    final totalFinal =
        invoices.fold<double>(0, (sum, inv) => sum + inv.finalAmount);
    _addRow(sheet, [
      'جمع کل',
      '',
      '',
      '',
      '',
      '',
      totalFinal.toStringAsFixed(0),
      '',
      '',
    ], isHeader: true);

    // ذخیره و اشتراک‌گذاری
    await _saveAndShare(excel, 'فاکتورها_${_today()}');
  }

  // ─── توابع کمکی ────────────────────────────────────────────────────────────

  /// اضافه کردن یک ردیف به شیت Excel
  /// isHeader: اگر true باشد سلول‌ها bold می‌شوند
  static void _addRow(
    Sheet sheet,
    List<String> values, {
    bool isHeader = false,
  }) {
    final rowIndex = sheet.maxRows;
    for (int col = 0; col < values.length; col++) {
      final cell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.value = TextCellValue(values[col]);
      // استایل برای هدر
      if (isHeader) {
        cell.cellStyle = CellStyle(bold: true);
      }
    }
  }

  /// ذخیره فایل Excel در مسیر موقت و اشتراک‌گذاری با share_plus
  static Future<void> _saveAndShare(
      Excel excel, String filename) async {
    try {
      // دریافت مسیر ذخیره‌سازی موقت
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$filename.xlsx';

      // نوشتن بایت‌های Excel به فایل
      final bytes = excel.save();
      if (bytes == null) {
        throw Exception('خطا در تولید فایل Excel');
      }

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // اشتراک‌گذاری فایل از طریق share_plus
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        text: 'فایل Excel از فروشگاه هوشمند',
      );
    } catch (e) {
      debugPrint('[ExcelService] خطا در ذخیره/اشتراک: $e');
      rethrow;
    }
  }

  /// تبدیل کلید تاریخ میلادی (YYYY-MM-DD) به شمسی
  static String _convertDateKey(String key) {
    try {
      final parts = key.split('-');
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      return DateConverter.toShamsi(date);
    } catch (_) {
      return key; // اگر تبدیل ناموفق بود، همان کلید را برگردان
    }
  }

  /// تاریخ امروز برای نام فایل (بدون کاراکترهای ویژه)
  static String _today() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }
}
