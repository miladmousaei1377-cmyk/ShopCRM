import 'dart:io';
import 'printer_service.dart';
import 'escpos_builder.dart';
import '../../domain/models/invoice.dart';

/// پرینتر وای‌فای از طریق TCP Socket روی پورت ۹۱۰۰
/// این استاندارد پرینتر JetDirect/RAW است و اکثر
/// پرینترهای حرارتی شبکه‌ای آن را پشتیبانی می‌کنند
class WiFiPrinterService extends PrinterService {
  final String ip;    // آدرس IP پرینتر (مثل ۱۹۲.۱۶۸.۱.۱۰۰)
  final int port;     // پورت (معمولاً ۹۱۰۰)
  Socket? _socket;   // اتصال TCP جاری

  WiFiPrinterService({required this.ip, required this.port});

  @override
  bool get isConnected => _socket != null;

  /// برقراری اتصال TCP به پرینتر
  @override
  Future<bool> connect() async {
    try {
      _socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      return true;
    } on SocketException catch (_) {
      _socket = null;
      return false; // پرینتر پیدا نشد یا خاموش است
    }
  }

  /// پرینت رسید فاکتور
  @override
  Future<void> printReceipt(
    Invoice invoice, {
    required String storeName,
    required String storePhone,
    required String storeAddress,
  }) async {
    await _ensureConnected();
    final bytes = await EscPosBuilder.buildReceiptBytes(
      invoice: invoice,
      storeName: storeName,
      storePhone: storePhone,
      storeAddress: storeAddress,
    );
    _socket!.add(bytes); // ارسال bytes به پرینتر
    await _socket!.flush(); // اطمینان از ارسال کامل
  }

  /// قطع اتصال
  @override
  Future<void> disconnect() async {
    await _socket?.flush();
    await _socket?.close();
    _socket = null;
  }

  /// اطمینان از برقراری اتصال قبل از پرینت
  Future<void> _ensureConnected() async {
    if (_socket == null) {
      final ok = await connect();
      if (!ok) throw Exception('اتصال به پرینتر برقرار نشد');
    }
  }

  /// تست سریع اتصال بدون پرینت (برای صفحه تنظیمات)
  Future<bool> testConnection() async {
    try {
      final socket = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 3));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// جستجوی خودکار پرینتر در شبکه محلی با اسکن پورت ۹۱۰۰
  /// [subnet]: مثلاً '192.168.1'
  static Future<List<String>> discoverPrinters({
    String subnet = '192.168.1',
    int port = 9100,
  }) async {
    final found = <String>[];
    final futures = <Future>[];

    // اسکن همزمان همه ۲۵۴ IP در subnet
    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';
      futures.add(
        Socket.connect(ip, port, timeout: const Duration(milliseconds: 200))
            .then((s) { found.add(ip); s.destroy(); })
            .catchError((_) {}), // IP پاسخ نداد → رد کن
      );
    }

    await Future.wait(futures);
    return found;
  }
}
