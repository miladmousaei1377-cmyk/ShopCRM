import 'dart:io';
import 'dart:async';
import 'printer_service.dart';
import 'escpos_builder.dart';
import '../../domain/models/invoice.dart';

class WiFiPrinterService extends PrinterService {
  final String ip;
  final int port;
  Socket? _socket;

  WiFiPrinterService({required this.ip, required this.port});

  @override
  bool get isConnected => _socket != null;

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
      return false;
    }
  }

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
    _socket!.add(bytes);
    await _socket!.flush();
  }

  @override
  Future<void> disconnect() async {
    await _socket?.flush();
    await _socket?.close();
    _socket = null;
  }

  Future<void> _ensureConnected() async {
    if (_socket == null) {
      final ok = await connect();
      if (!ok) throw Exception('اتصال به پرینتر ناموفق بود');
    }
  }

  /// تست اتصال بدون پرینت
  Future<bool> testConnection() async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 3));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// auto-discover پرینترها با UDP broadcast (ساختار اولیه)
  static Future<List<String>> discoverPrinters({
    String subnet = '192.168.1',
    int port = 9100,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final found = <String>[];
    final futures = <Future>[];
    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';
      futures.add(
        Socket.connect(ip, port, timeout: const Duration(milliseconds: 200))
            .then((s) { found.add(ip); s.destroy(); })
            .catchError((_) {}),
      );
    }
    await Future.wait(futures);
    return found;
  }
}
