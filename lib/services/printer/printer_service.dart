import '../../domain/models/invoice.dart';

abstract class PrinterService {
  Future<bool> connect();
  Future<void> printReceipt(Invoice invoice, {
    required String storeName,
    required String storePhone,
    required String storeAddress,
  });
  Future<void> disconnect();
  bool get isConnected;
}
