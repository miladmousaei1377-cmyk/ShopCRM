import 'dart:io';
import 'printer_service.dart';
import 'escpos_builder.dart';
import '../../domain/models/invoice.dart';

/// سرویس پرینتر بلوتوث با flutter_blue_plus
/// روی ویندوز غیرفعال می‌شود (WiFi اولویت دارد)
class BluetoothPrinterService extends PrinterService {
  final String deviceId;
  final String deviceName;
  bool _connected = false;

  BluetoothPrinterService({
    required this.deviceId,
    required this.deviceName,
  });

  @override
  bool get isConnected => _connected;

  @override
  Future<bool> connect() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // بلوتوث BLE روی دسکتاپ پشتیبانی محدود دارد
      return false;
    }
    try {
      // TODO: اتصال واقعی با flutter_blue_plus
      // final device = BluetoothDevice.fromId(deviceId);
      // await device.connect(timeout: const Duration(seconds: 10));
      // final services = await device.discoverServices();
      // پیدا کردن characteristic مناسب برای write
      _connected = true;
      return true;
    } catch (_) {
      _connected = false;
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
    if (!_connected) throw Exception('پرینتر متصل نیست');
    final bytes = await EscPosBuilder.buildReceiptBytes(
      invoice: invoice,
      storeName: storeName,
      storePhone: storePhone,
      storeAddress: storeAddress,
    );
    // TODO: ارسال bytes به characteristic بلوتوث
    // await _characteristic?.write(bytes, withoutResponse: false);
  }

  @override
  Future<void> disconnect() async {
    // TODO: await device.disconnect();
    _connected = false;
  }

  /// اسکن دستگاه‌های بلوتوث اطراف
  static Stream<List<Map<String, String>>> scanDevices() async* {
    if (Platform.isWindows) { yield []; return; }
    // TODO: FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    // yield* FlutterBluePlus.scanResults.map((results) =>
    //   results.map((r) => {'id': r.device.remoteId.str, 'name': r.device.platformName}).toList()
    // );
    yield [];
  }
}
