import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import '../../domain/models/invoice.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_converter.dart';

/// ساخت دستورات ESC/POS برای پرینتر حرارتی
/// چون پرینترهای حرارتی ارزان از فونت فارسی پشتیبانی نمی‌کنند،
/// متن فارسی را به bitmap رندر کرده و به صورت رستر می‌فرستیم
class EscPosBuilder {
  // دستورات ESC/POS پایه
  static final _init = Uint8List.fromList([0x1B, 0x40]);
  static final _cut = Uint8List.fromList([0x1D, 0x56, 0x41, 0x00]);
  static final _feedLines = (int n) => Uint8List.fromList([0x1B, 0x64, n]);
  static final _centerAlign = Uint8List.fromList([0x1B, 0x61, 0x01]);
  static final _leftAlign = Uint8List.fromList([0x1B, 0x61, 0x00]);
  static final _rightAlign = Uint8List.fromList([0x1B, 0x61, 0x02]);
  static final _boldOn = Uint8List.fromList([0x1B, 0x45, 0x01]);
  static final _boldOff = Uint8List.fromList([0x1B, 0x45, 0x00]);
  static final _doubleHeight = Uint8List.fromList([0x1B, 0x21, 0x10]);
  static final _normalSize = Uint8List.fromList([0x1B, 0x21, 0x00]);

  /// ساخت رسید کامل به صورت image bytes برای پرینت رستر
  static Future<Uint8List> buildReceiptBytes({
    required Invoice invoice,
    required String storeName,
    required String storePhone,
    required String storeAddress,
    int paperWidthPx = 384, // عرض استاندارد ۸۰mm = ۵۷۶px | ۵۸mm = ۳۸۴px
  }) async {
    // رندر متن فارسی به canvas و سپس به bytes
    final imageBytes = await _renderReceiptToImage(
      invoice: invoice,
      storeName: storeName,
      storePhone: storePhone,
      storeAddress: storeAddress,
      width: paperWidthPx.toDouble(),
    );

    final List<int> bytes = [];

    // Initialize
    bytes.addAll(_init);

    // Print image using GS v 0 (raster bit image)
    bytes.addAll(_imageToEscPos(imageBytes, paperWidthPx));

    // Feed and cut
    bytes.addAll(_feedLines(4));
    bytes.addAll(_cut);

    return Uint8List.fromList(bytes);
  }

  /// رندر رسید به PNG bytes
  static Future<Uint8List> _renderReceiptToImage({
    required Invoice invoice,
    required String storeName,
    required String storePhone,
    required String storeAddress,
    required double width,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()..color = Colors.white;
    double y = 0;
    const double lineH = 28;
    const double smallLineH = 22;
    const double padding = 8;

    // پس‌زمینه سفید (تخمین ارتفاع)
    final estimatedHeight = 600 + invoice.items.length * 50.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, estimatedHeight), paint);

    void drawText(
      String text, {
      double fontSize = 14,
      bool bold = false,
      bool center = false,
      double? x,
      Color color = Colors.black,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
            fontFamily: 'Vazirmatn',
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: center ? TextAlign.center : TextAlign.right,
      );
      tp.layout(maxWidth: width - padding * 2);
      final dx = center
          ? (width - tp.width) / 2
          : (x ?? padding);
      tp.paint(canvas, Offset(dx, y));
    }

    void drawDivider() {
      final linePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 0.5;
      canvas.drawLine(
        Offset(padding, y + lineH / 2),
        Offset(width - padding, y + lineH / 2),
        linePaint,
      );
      y += lineH / 2;
    }

    // هدر
    drawText(storeName, fontSize: 20, bold: true, center: true);
    y += lineH + 4;
    if (storeAddress.isNotEmpty) {
      drawText(storeAddress, fontSize: 12, center: true);
      y += smallLineH;
    }
    if (storePhone.isNotEmpty) {
      drawText('تلفن: $storePhone', fontSize: 12, center: true);
      y += smallLineH;
    }
    y += 4;
    drawDivider();
    y += 4;

    // اطلاعات فاکتور
    drawText('شماره فاکتور: ${invoice.invoiceNumber}', fontSize: 13, center: true);
    y += smallLineH;
    drawText('تاریخ: ${DateConverter.toShamsiWithTime(invoice.createdAt)}', fontSize: 12, center: true);
    y += smallLineH;
    if (invoice.customerName != null) {
      drawText('مشتری: ${invoice.customerName}', fontSize: 12, center: true);
      y += smallLineH;
    }
    y += 4;
    drawDivider();
    y += 4;

    // آیتم‌ها
    for (final item in invoice.items) {
      final qty = item.quantity.toString();
      final price = CurrencyFormatter.formatNumber(item.unitPrice);
      final total = CurrencyFormatter.formatNumber(item.subtotal);
      drawText(item.productName, fontSize: 13, bold: true);
      y += smallLineH;
      drawText('$qty × $price = $total تومان', fontSize: 12);
      y += smallLineH - 4;
    }
    y += 4;
    drawDivider();
    y += 4;

    // جمع
    drawText('جمع کل: ${CurrencyFormatter.format(invoice.totalAmount)}', fontSize: 13);
    y += smallLineH;
    if (invoice.discountAmount > 0) {
      drawText('تخفیف: ${CurrencyFormatter.format(invoice.discountAmount)}', fontSize: 12);
      y += smallLineH;
    }
    drawText('مبلغ نهایی: ${CurrencyFormatter.format(invoice.finalAmount)}',
        fontSize: 16, bold: true);
    y += lineH;
    drawText('روش پرداخت: ${invoice.paymentMethod.label}', fontSize: 12);
    y += smallLineH;
    y += 4;
    drawDivider();
    y += 8;

    // فوتر
    drawText('با تشکر از خرید شما', fontSize: 14, center: true, bold: true);
    y += lineH;
    drawText('فروشگاه هوشمند', fontSize: 12, center: true);
    y += smallLineH;

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), (y + 20).toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// تبدیل PNG bytes به دستورات ESC/POS GS v 0
  static List<int> _imageToEscPos(Uint8List pngBytes, int widthPx) {
    // نکته: برای تبدیل واقعی PNG به monochrome bitmap و ESC/POS
    // به کتابخانه image نیاز است که در یک پیاده‌سازی کامل استفاده می‌شود.
    // اینجا ساختار کلی را پیاده می‌کنیم.

    final List<int> result = [];
    // GS v 0 header
    final widthBytes = widthPx ~/ 8;
    result.addAll([
      0x1D, 0x76, 0x30, 0x00, // GS v 0
      widthBytes & 0xFF, (widthBytes >> 8) & 0xFF, // xL, xH
      0x00, 0x00, // yL, yH (موقتی)
    ]);
    // TODO: اضافه کردن pixel data واقعی
    return result;
  }

  /// ساخت bytes متنی ساده (فقط ASCII) برای تست پرینتر
  static Uint8List buildTestPrint(String storeName) {
    final List<int> bytes = [];
    bytes.addAll(_init);
    bytes.addAll(_centerAlign);
    bytes.addAll(_boldOn);
    bytes.addAll(_doubleHeight);
    // ASCII only
    bytes.addAll('TEST PRINT\n'.codeUnits);
    bytes.addAll(_normalSize);
    bytes.addAll(_boldOff);
    bytes.addAll('Printer working OK\n'.codeUnits);
    bytes.addAll(_leftAlign);
    bytes.addAll(_feedLines(3));
    bytes.addAll(_cut);
    return Uint8List.fromList(bytes);
  }
}
