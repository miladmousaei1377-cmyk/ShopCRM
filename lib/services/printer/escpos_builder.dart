import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as image;
import '../../domain/models/invoice.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_converter.dart';

/// سازنده دستورات ESC/POS برای پرینترهای حرارتی
///
/// چرا از رستر (image) استفاده می‌کنیم؟
/// پرینترهای حرارتی ارزان‌قیمت فونت فارسی ندارند.
/// راه‌حل: متن فارسی را با Canvas روی PNG رندر کرده
/// و سپس به صورت تصویر (GS v 0) به پرینتر می‌فرستیم.
class EscPosBuilder {
  // ─── دستورات پایه ESC/POS ────────────────────────────────────
  static final _init = Uint8List.fromList([0x1B, 0x40]); // Initialize
  static final _cut = Uint8List.fromList([0x1D, 0x56, 0x41, 0x00]); // برش کاغذ
  static Uint8List _feedLines(int n) =>
      Uint8List.fromList([0x1B, 0x64, n]); // پیشروی n خط
  static final _centerAlign = Uint8List.fromList([0x1B, 0x61, 0x01]); // وسط‌چین
  static final _leftAlign = Uint8List.fromList([0x1B, 0x61, 0x00]); // چپ‌چین
  static final _boldOn = Uint8List.fromList([0x1B, 0x45, 0x01]); // پررنگ روشن
  static final _boldOff = Uint8List.fromList([0x1B, 0x45, 0x00]); // پررنگ خاموش
  static final _doubleHeight =
      Uint8List.fromList([0x1B, 0x21, 0x10]); // ارتفاع دو برابر
  static final _normalSize =
      Uint8List.fromList([0x1B, 0x21, 0x00]); // سایز عادی

  /// ساخت bytes کامل رسید برای ارسال به پرینتر
  /// [paperWidthPx]: عرض کاغذ به پیکسل (۵۸mm=۳۸۴ | ۸۰mm=۵۷۶)
  static Future<Uint8List> buildReceiptBytes({
    required Invoice invoice,
    required String storeName,
    required String storePhone,
    required String storeAddress,
    int paperWidthPx = 384,
  }) async {
    // ابتدا رسید را به PNG رندر کن
    final imageBytes = await _renderReceiptToImage(
      invoice: invoice,
      storeName: storeName,
      storePhone: storePhone,
      storeAddress: storeAddress,
      width: paperWidthPx.toDouble(),
    );

    final List<int> bytes = [];
    bytes.addAll(_init); // Initialize پرینتر

    // ارسال تصویر با دستور GS v 0
    bytes.addAll(_imageToEscPos(imageBytes, paperWidthPx));

    // پیشروی و برش
    bytes.addAll(_feedLines(4));
    bytes.addAll(_cut);

    return Uint8List.fromList(bytes);
  }

  /// رندر محتوای رسید روی Canvas و تبدیل به PNG bytes
  static Future<Uint8List> _renderReceiptToImage({
    required Invoice invoice,
    required String storeName,
    required String storePhone,
    required String storeAddress,
    required double width,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // پس‌زمینه سفید
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, 800),
      Paint()..color = Colors.white,
    );

    double y = 0;
    const double lineH = 28; // ارتفاع خط معمولی
    const double smallLineH = 22; // ارتفاع خط کوچک
    const double padding = 8;

    // تابع کمکی رسم متن
    double drawText(
      String text, {
      double fontSize = 14,
      bool bold = false,
      bool center = false,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: Colors.black,
            fontFamily: 'Vazirmatn',
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: center ? TextAlign.center : TextAlign.right,
      );
      tp.layout(maxWidth: width - padding * 2);
      final dx = center ? (width - tp.width) / 2 : padding;
      tp.paint(canvas, Offset(dx, y));
      return tp.height;
    }

    // تابع کمکی رسم خط جداکننده
    void drawDivider() {
      canvas.drawLine(
        Offset(padding, y + lineH / 2),
        Offset(width - padding, y + lineH / 2),
        Paint()
          ..color = Colors.black
          ..strokeWidth = 0.5,
      );
      y += lineH / 2;
    }

    // ─── هدر رسید ────────────────────────────────────────────
    y += drawText(storeName, fontSize: 20, bold: true, center: true) + 4;
    if (storeAddress.isNotEmpty) {
      y += drawText(storeAddress, fontSize: 12, center: true)
          .clamp(smallLineH, double.infinity);
    }
    if (storePhone.isNotEmpty) {
      y += drawText('تلفن: $storePhone', fontSize: 12, center: true)
          .clamp(smallLineH, double.infinity);
    }
    y += 4;
    drawDivider();
    y += 4;

    // ─── شماره و تاریخ فاکتور ────────────────────────────────
    y += drawText('شماره فاکتور: ${invoice.invoiceNumber}',
            fontSize: 13, center: true)
        .clamp(smallLineH, double.infinity);
    y += drawText('تاریخ: ${DateConverter.toShamsiWithTime(invoice.createdAt)}',
            fontSize: 12, center: true)
        .clamp(smallLineH, double.infinity);
    if (invoice.customerName != null) {
      y +=
          drawText('مشتری: ${invoice.customerName}', fontSize: 12, center: true)
              .clamp(smallLineH, double.infinity);
    }
    y += 4;
    drawDivider();
    y += 4;

    // ─── آیتم‌های فاکتور ──────────────────────────────────────
    for (final item in invoice.items) {
      final qty = item.quantity.toString();
      final price = CurrencyFormatter.formatNumber(item.unitPrice);
      final total = CurrencyFormatter.formatNumber(item.subtotal);
      y += drawText(item.productName, fontSize: 13, bold: true)
          .clamp(smallLineH, double.infinity);
      y += drawText('$qty × $price = $total تومان', fontSize: 12)
          .clamp(smallLineH - 4, double.infinity);
    }
    y += 4;
    drawDivider();
    y += 4;

    // ─── جمع و مبالغ نهایی ───────────────────────────────────
    y += drawText('جمع کل: ${CurrencyFormatter.format(invoice.totalAmount)}',
            fontSize: 13)
        .clamp(smallLineH, double.infinity);
    if (invoice.discountAmount > 0) {
      y += drawText(
              'تخفیف: ${CurrencyFormatter.format(invoice.discountAmount)}',
              fontSize: 12)
          .clamp(smallLineH, double.infinity);
    }
    y += drawText(
            'مبلغ نهایی: ${CurrencyFormatter.format(invoice.finalAmount)}',
            fontSize: 16,
            bold: true)
        .clamp(lineH, double.infinity);
    y += drawText('روش پرداخت: ${invoice.paymentMethod.label}', fontSize: 12)
        .clamp(smallLineH, double.infinity);
    y += 4;
    drawDivider();
    y += 8;

    // ─── فوتر ─────────────────────────────────────────────────
    y += drawText('با تشکر از خرید شما', fontSize: 14, center: true, bold: true)
        .clamp(lineH, double.infinity);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), (y + 20).toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// تبدیل PNG bytes به دستورات ESC/POS رستر (GS v 0)
  static List<int> _imageToEscPos(Uint8List pngBytes, int widthPx) {
    final decoded = image.decodePng(pngBytes);
    if (decoded == null) throw const FormatException('تصویر رسید معتبر نیست');
    final widthBytes = (widthPx + 7) ~/ 8;
    final height = decoded.height;
    final result = <int>[
      0x1D, 0x76, 0x30, 0x00, // GS v 0 — دستور print raster image
      widthBytes & 0xFF, // xL: بایت‌های عرض (کم‌ارزش)
      (widthBytes >> 8) & 0xFF, // xH: بایت‌های عرض (پرارزش)
      height & 0xFF,
      (height >> 8) & 0xFF,
    ];
    for (var y = 0; y < height; y++) {
      for (var byteX = 0; byteX < widthBytes; byteX++) {
        var value = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = byteX * 8 + bit;
          if (x >= decoded.width) continue;
          final pixel = decoded.getPixel(x, y);
          final luminance =
              (pixel.r * 299 + pixel.g * 587 + pixel.b * 114) / 1000;
          if (pixel.a > 127 && luminance < 160) value |= 0x80 >> bit;
        }
        result.add(value);
      }
    }
    return result;
  }

  /// رسید متنی ASCII برای تست ساده پرینتر (بدون فارسی)
  static Uint8List buildTestPrint(String storeName) {
    final List<int> bytes = [];
    bytes.addAll(_init);
    bytes.addAll(_centerAlign);
    bytes.addAll(_boldOn);
    bytes.addAll(_doubleHeight);
    bytes.addAll('TEST PRINT OK\n'.codeUnits); // متن ASCII
    bytes.addAll(_normalSize);
    bytes.addAll(_boldOff);
    bytes.addAll('Printer is working.\n'.codeUnits);
    bytes.addAll(_leftAlign);
    bytes.addAll(_feedLines(3));
    bytes.addAll(_cut);
    return Uint8List.fromList(bytes);
  }
}
