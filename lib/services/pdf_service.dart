/// سرویس تولید PDF برای فاکتور و گزارش‌های فروش
/// از پکیج pdf و printing استفاده می‌کند
/// برای فونت فارسی تلاش می‌شود از فایل محلی بارگذاری شود
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants/app_strings.dart';
import '../core/utils/date_converter.dart';
import '../domain/models/invoice.dart';
import '../data/repositories/report_repository.dart';

class PdfService {
  PdfService._();

  // ─── تولید PDF فاکتور ───────────────────────────────────────────────────────

  /// تبدیل یک فاکتور به بایت‌های PDF
  /// شامل هدر فروشگاه، جدول اقلام و خلاصه مالی
  static Future<Uint8List> buildInvoicePdf(Invoice invoice) async {
    final pdf = pw.Document();

    // بارگذاری فونت فارسی — اگر فایل نبود از فونت پیش‌فرض استفاده می‌شود
    // TODO: اگر فونت Vazirmatn در assets قرار گرفت، اینجا بارگذاری کنید
    pw.Font? persianFont;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      persianFont = pw.Font.ttf(fontData);
    } catch (_) {
      // فونت یافت نشد — از فونت پیش‌فرض استفاده می‌شود
      persianFont = null;
    }

    // سبک متن — با فونت فارسی یا پیش‌فرض
    final textStyle = pw.TextStyle(
      font: persianFont,
      fontSize: 10,
    );
    final headerStyle = pw.TextStyle(
      font: persianFont,
      fontSize: 16,
      fontWeight: pw.FontWeight.bold,
    );
    final subHeaderStyle = pw.TextStyle(
      font: persianFont,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    );

    // صفحه اصلی PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        // جهت RTL — متأسفانه pdf package پشتیبانی کامل RTL ندارد
        // بنابراین متون فارسی بصورت LTR نمایش داده می‌شوند
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ─── هدر: نام فروشگاه و اطلاعات فاکتور ──────────────
              _buildPdfHeader(invoice, headerStyle, subHeaderStyle, textStyle),
              pw.SizedBox(height: 20),

              // ─── جدول اقلام فاکتور ───────────────────────────────
              _buildItemsTable(invoice, textStyle),
              pw.SizedBox(height: 20),

              // ─── خلاصه مالی ──────────────────────────────────────
              _buildFinancialFooter(invoice, textStyle, subHeaderStyle),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// هدر PDF: نام فروشگاه، شماره فاکتور، تاریخ، مشتری
  static pw.Widget _buildPdfHeader(
    Invoice invoice,
    pw.TextStyle headerStyle,
    pw.TextStyle subHeaderStyle,
    pw.TextStyle textStyle,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // نام فروشگاه
        pw.Center(
          child: pw.Text(
            AppStrings.appName,
            style: headerStyle,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Divider(color: PdfColors.black, thickness: 1),
        ),
        pw.SizedBox(height: 8),
        // اطلاعات فاکتور در دو ستون
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    'Invoice No: ${invoice.invoiceNumber}',
                    style: textStyle),
                pw.Text(
                    'Date: ${DateConverter.toShamsi(invoice.createdAt)}',
                    style: textStyle),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                    'Customer: ${invoice.customerName ?? "Walk-in"}',
                    style: textStyle),
                pw.Text(
                    'Payment: ${invoice.paymentMethod.label}',
                    style: textStyle),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// جدول اقلام فاکتور با هدر ستون‌ها
  static pw.Widget _buildItemsTable(
      Invoice invoice, pw.TextStyle textStyle) {
    // هدر جدول
    final headerRow = pw.TableRow(
      decoration:
          const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        _tableCell('Product', textStyle, isHeader: true),
        _tableCell('Qty', textStyle, isHeader: true),
        _tableCell('Unit Price', textStyle, isHeader: true),
        _tableCell('Subtotal', textStyle, isHeader: true),
      ],
    );

    // ردیف‌های اقلام
    final itemRows = invoice.items.map((item) {
      return pw.TableRow(
        children: [
          _tableCell(item.productName, textStyle),
          _tableCell('${item.quantity}', textStyle),
          _tableCell(
              '${item.unitPrice.toStringAsFixed(0)} T', textStyle),
          _tableCell(
              '${item.subtotal.toStringAsFixed(0)} T', textStyle),
        ],
      );
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(
          color: PdfColors.grey400, width: 0.5),
      children: [headerRow, ...itemRows],
    );
  }

  /// یک سلول جدول PDF
  static pw.Widget _tableCell(
      String text, pw.TextStyle style,
      {bool isHeader = false}) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(
        text,
        style: isHeader
            ? style.copyWith(fontWeight: pw.FontWeight.bold)
            : style,
      ),
    );
  }

  /// پاورقی مالی: جمع کل، تخفیف، مالیات، مبلغ نهایی
  static pw.Widget _buildFinancialFooter(
    Invoice invoice,
    pw.TextStyle textStyle,
    pw.TextStyle subHeaderStyle,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border:
            pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          // جمع کل
          _summaryLine(
              'Total:', '${invoice.totalAmount.toStringAsFixed(0)} T',
              textStyle),
          // تخفیف
          if (invoice.discountAmount > 0)
            _summaryLine(
                'Discount:',
                '- ${invoice.discountAmount.toStringAsFixed(0)} T',
                textStyle),
          // مالیات
          if (invoice.taxAmount > 0)
            _summaryLine(
                'Tax:',
                '+ ${invoice.taxAmount.toStringAsFixed(0)} T',
                textStyle),
          // خط جدا
          pw.Divider(color: PdfColors.black),
          // مبلغ نهایی
          _summaryLine(
              'Final Amount:',
              '${invoice.finalAmount.toStringAsFixed(0)} T',
              subHeaderStyle),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(AppStrings.receiptThankYou, style: textStyle),
          ),
        ],
      ),
    );
  }

  /// یک ردیف خلاصه مالی در PDF
  static pw.Widget _summaryLine(
      String label, String value, pw.TextStyle style) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  // ─── تولید PDF گزارش فروش ──────────────────────────────────────────────────

  /// تبدیل گزارش فروش به بایت‌های PDF
  /// شامل خلاصه آمار و جدول پرفروش‌ترین محصولات
  static Future<Uint8List> buildSalesReportPdf(
    SalesReport report,
    DateTime from,
    DateTime to,
  ) async {
    final pdf = pw.Document();

    // بارگذاری فونت (مشابه قبل)
    pw.Font? persianFont;
    try {
      final fontData =
          await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      persianFont = pw.Font.ttf(fontData);
    } catch (_) {
      persianFont = null;
    }

    final textStyle = pw.TextStyle(font: persianFont, fontSize: 10);
    final headerStyle = pw.TextStyle(
        font: persianFont,
        fontSize: 14,
        fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // عنوان گزارش
              pw.Center(
                child: pw.Text(
                  '${AppStrings.appName} - Sales Report',
                  style: headerStyle,
                ),
              ),
              pw.SizedBox(height: 8),
              // بازه زمانی
              pw.Text(
                'Period: ${DateConverter.toShamsi(from)} to ${DateConverter.toShamsi(to)}',
                style: textStyle,
              ),
              pw.SizedBox(height: 16),

              // ─── خلاصه آمار ──────────────────────────────────
              pw.Text('Summary', style: headerStyle),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                      'Total Sales: ${report.totalSales.toStringAsFixed(0)} T',
                      style: textStyle),
                  pw.Text(
                      'Invoices: ${report.totalInvoices}',
                      style: textStyle),
                ],
              ),
              pw.SizedBox(height: 16),

              // ─── جدول پرفروش‌ترین محصولات ─────────────────────
              pw.Text('Top Products', style: headerStyle),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColors.grey400, width: 0.5),
                children: [
                  // هدر جدول
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300),
                    children: [
                      _tableCell('Product', textStyle,
                          isHeader: true),
                      _tableCell('Qty', textStyle, isHeader: true),
                      _tableCell('Revenue', textStyle,
                          isHeader: true),
                    ],
                  ),
                  // داده‌های محصولات
                  ...report.topProducts.map((p) => pw.TableRow(
                        children: [
                          _tableCell(p.productName, textStyle),
                          _tableCell('${p.totalQuantity}', textStyle),
                          _tableCell(
                              '${p.totalRevenue.toStringAsFixed(0)} T',
                              textStyle),
                        ],
                      )),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ─── ذخیره و اشتراک‌گذاری PDF ──────────────────────────────────────────────

  /// ذخیره یا اشتراک‌گذاری PDF با استفاده از پکیج printing
  static Future<void> savePdf(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: '$filename.pdf');
  }

  /// تولید و اشتراک‌گذاری PDF فاکتور — shortcut برای صفحه جزئیات
  static Future<void> shareInvoicePdf(Invoice invoice) async {
    final bytes = await buildInvoicePdf(invoice);
    await savePdf(bytes, 'invoice_${invoice.invoiceNumber}');
  }

  /// تولید و اشتراک‌گذاری PDF گزارش فروش
  static Future<void> shareSalesReport({
    required SalesReport report,
    required DateTime from,
    required DateTime to,
  }) async {
    final bytes = await buildSalesReportPdf(report, from, to);
    await savePdf(
      bytes,
      'sales_report_${from.year}${from.month.toString().padLeft(2,'0')}${from.day.toString().padLeft(2,'0')}',
    );
  }
}
