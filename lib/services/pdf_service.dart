/// سرویس تولید PDF برای فاکتور و گزارش‌های فروش
/// از پکیج pdf و printing استفاده می‌کند
/// متون کاملاً فارسی — راست به چپ
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants/app_strings.dart';
import '../core/utils/date_converter.dart';
import '../core/utils/currency_formatter.dart';
import '../domain/models/invoice.dart';
import '../data/repositories/report_repository.dart';

class PdfService {
  PdfService._();

  static Future<pw.Font?> _loadFont() async {
    try {
      final data = await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
      return pw.Font.ttf(data);
    } catch (_) {
      return null;
    }
  }

  // ─── تولید PDF فاکتور ───────────────────────────────────────────────────────

  static Future<Uint8List> buildInvoicePdf(Invoice invoice) async {
    final pdf = pw.Document();
    final font = await _loadFont();

    final body = pw.TextStyle(font: font, fontSize: 10);
    final bold = pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold);
    final title = pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold);
    final sub   = pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // ─── سربرگ ───────────────────────────────────────────────────
            pw.Center(child: pw.Text(AppStrings.appName, style: title, textDirection: pw.TextDirection.rtl)),
            pw.SizedBox(height: 4),
            pw.Divider(color: PdfColors.black, thickness: 1),
            pw.SizedBox(height: 8),

            // اطلاعات فاکتور در دو ستون
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _rtlText('مشتری: ${invoice.customerName ?? "مشتری عادی"}', body),
                    pw.SizedBox(height: 2),
                    _rtlText('روش پرداخت: ${invoice.paymentMethod.label}', body),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _rtlText('شماره فاکتور: ${invoice.invoiceNumber}', bold),
                    pw.SizedBox(height: 2),
                    _rtlText('تاریخ: ${DateConverter.toShamsi(invoice.createdAt)}', body),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // ─── جدول اقلام ──────────────────────────────────────────────
            _buildItemsTable(invoice, body, bold),
            pw.SizedBox(height: 16),

            // ─── خلاصه مالی ──────────────────────────────────────────────
            _buildFinancialFooter(invoice, body, sub),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  static pw.Widget _buildItemsTable(Invoice invoice, pw.TextStyle body, pw.TextStyle bold) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _tableCell('محصول', bold, align: pw.TextAlign.right),
            _tableCell('تعداد', bold, align: pw.TextAlign.center),
            _tableCell('قیمت واحد', bold, align: pw.TextAlign.center),
            _tableCell('جمع جزء', bold, align: pw.TextAlign.center),
          ],
        ),
        ...invoice.items.map((item) => pw.TableRow(
          children: [
            _tableCell(item.productName, body, align: pw.TextAlign.right),
            _tableCell('${item.quantity}', body, align: pw.TextAlign.center),
            _tableCell('${CurrencyFormatter.formatNumber(item.unitPrice.toInt())} ت', body, align: pw.TextAlign.center),
            _tableCell('${CurrencyFormatter.formatNumber(item.subtotal.toInt())} ت', body, align: pw.TextAlign.center),
          ],
        )),
      ],
    );
  }

  static pw.Widget _tableCell(String text, pw.TextStyle style,
      {pw.TextAlign align = pw.TextAlign.right}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  static pw.Widget _buildFinancialFooter(
      Invoice invoice, pw.TextStyle body, pw.TextStyle sub) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _summaryRow('جمع کل:', '${CurrencyFormatter.formatNumber(invoice.totalAmount.toInt())} تومان', body),
          if (invoice.discountAmount > 0)
            _summaryRow('تخفیف:', '${CurrencyFormatter.formatNumber(invoice.discountAmount.toInt())} تومان', body),
          if (invoice.taxAmount > 0)
            _summaryRow('مالیات:', '${CurrencyFormatter.formatNumber(invoice.taxAmount.toInt())} تومان', body),
          pw.Divider(color: PdfColors.black),
          _summaryRow('مبلغ نهایی:', '${CurrencyFormatter.formatNumber(invoice.finalAmount.toInt())} تومان', sub),
          pw.SizedBox(height: 8),
          pw.Center(child: _rtlText(AppStrings.receiptThankYou, body)),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(value, style: style),
          _rtlText(label, style),
        ],
      ),
    );
  }

  static pw.Widget _rtlText(String text, pw.TextStyle style) {
    return pw.Text(text, style: style, textAlign: pw.TextAlign.right);
  }

  // ─── تولید PDF گزارش فروش ──────────────────────────────────────────────────

  static Future<Uint8List> buildSalesReportPdf(
      SalesReport report, DateTime from, DateTime to) async {
    final pdf = pw.Document();
    final font = await _loadFont();

    final body   = pw.TextStyle(font: font, fontSize: 10);
    final bold   = pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold);
    final header = pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // عنوان
            pw.Center(
              child: _rtlText('${AppStrings.appName} - گزارش فروش', header),
            ),
            pw.SizedBox(height: 8),
            _rtlText('بازه زمانی: ${DateConverter.toShamsi(from)} تا ${DateConverter.toShamsi(to)}', body),
            pw.SizedBox(height: 16),

            // خلاصه آمار
            _rtlText('خلاصه', header),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('${report.totalInvoices} فاکتور', style: body),
                _rtlText('جمع فروش: ${CurrencyFormatter.formatNumber(report.totalSales.toInt())} تومان', body),
              ],
            ),
            pw.SizedBox(height: 16),

            // جدول پرفروش‌ترین محصولات
            _rtlText('پرفروش‌ترین محصولات', header),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _tableCell('محصول', bold, align: pw.TextAlign.right),
                    _tableCell('تعداد', bold, align: pw.TextAlign.center),
                    _tableCell('درآمد (تومان)', bold, align: pw.TextAlign.center),
                  ],
                ),
                ...report.topProducts.map((p) => pw.TableRow(
                  children: [
                    _tableCell(p.productName, body, align: pw.TextAlign.right),
                    _tableCell('${p.totalQuantity}', body, align: pw.TextAlign.center),
                    _tableCell(CurrencyFormatter.formatNumber(p.totalRevenue.toInt()), body, align: pw.TextAlign.center),
                  ],
                )),
              ],
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  // ─── ذخیره و اشتراک‌گذاری ──────────────────────────────────────────────────

  static Future<void> savePdf(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: '$filename.pdf');
  }

  static Future<void> shareInvoicePdf(Invoice invoice) async {
    final bytes = await buildInvoicePdf(invoice);
    await savePdf(bytes, 'فاکتور_${invoice.invoiceNumber}');
  }

  static Future<void> shareSalesReport({
    required SalesReport report,
    required DateTime from,
    required DateTime to,
  }) async {
    final bytes = await buildSalesReportPdf(report, from, to);
    await savePdf(
      bytes,
      'گزارش_فروش_${from.year}${from.month.toString().padLeft(2, '0')}${from.day.toString().padLeft(2, '0')}',
    );
  }
}
