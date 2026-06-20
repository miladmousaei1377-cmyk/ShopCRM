import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'printer_service.dart';
import 'escpos_builder.dart';
import '../../domain/models/invoice.dart';

/// پرینتر USB/کابل از طریق Windows Printer API
/// پرینتر باید در ویندوز نصب و به عنوان Printer شناخته شده باشد
class UsbPrinterService extends PrinterService {
  final String printerName;
  bool _connected = false;

  UsbPrinterService({required this.printerName});

  @override
  bool get isConnected => _connected;

  @override
  Future<bool> connect() async {
    if (printerName.isEmpty) return false;
    if (Platform.isWindows) {
      // بررسی وجود پرینتر در لیست ویندوز
      final result = await Process.run(
        'wmic', ['printer', 'where', 'name="$printerName"', 'get', 'name'],
      );
      _connected = result.stdout.toString().contains(printerName);
      return _connected;
    }
    return false;
  }

  @override
  Future<void> printReceipt(Invoice invoice, {
    required String storeName,
    required String storePhone,
    required String storeAddress,
  }) async {
    final bytes = EscPosBuilder.buildReceipt(
      invoice,
      storeName: storeName,
      storePhone: storePhone,
      storeAddress: storeAddress,
    );
    await _sendRaw(bytes);
  }

  /// ارسال داده خام ESC/POS به پرینتر از طریق Windows RAW printing
  Future<void> _sendRaw(List<int> bytes) async {
    final temp = await getTemporaryDirectory();
    final file = File('${temp.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.bin');
    await file.writeAsBytes(bytes);
    if (Platform.isWindows) {
      await Process.run(
        'cmd', ['/c', 'copy', '/b', file.path, r'\\.\' + printerName],
      );
    }
    await file.delete().catchError((_) => file);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  /// لیست تمام پرینترهای نصب‌شده در ویندوز
  static Future<List<String>> listWindowsPrinters() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await Process.run(
        'wmic', ['printer', 'get', 'name'],
        stdoutEncoding: const SystemEncoding(),
      );
      final lines = result.stdout.toString().split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l != 'Name')
          .toList();
      return lines;
    } catch (_) {
      return [];
    }
  }
}
