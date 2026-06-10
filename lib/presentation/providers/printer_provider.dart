import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/printer/printer_service.dart';
import '../../services/printer/bluetooth_printer_service.dart';
import '../../services/printer/wifi_printer_service.dart';

enum PrinterType { bluetooth, wifi }

class PrinterSettings {
  final PrinterType type;
  final String? bluetoothDeviceId;
  final String? bluetoothDeviceName;
  final String wifiIp;
  final int wifiPort;
  final String storeName;
  final String storePhone;
  final String storeAddress;

  const PrinterSettings({
    this.type = PrinterType.wifi,
    this.bluetoothDeviceId,
    this.bluetoothDeviceName,
    this.wifiIp = '192.168.1.100',
    this.wifiPort = 9100,
    this.storeName = 'فروشگاه هوشمند',
    this.storePhone = '',
    this.storeAddress = '',
  });

  PrinterSettings copyWith({
    PrinterType? type,
    String? bluetoothDeviceId,
    String? bluetoothDeviceName,
    String? wifiIp,
    int? wifiPort,
    String? storeName,
    String? storePhone,
    String? storeAddress,
  }) {
    return PrinterSettings(
      type: type ?? this.type,
      bluetoothDeviceId: bluetoothDeviceId ?? this.bluetoothDeviceId,
      bluetoothDeviceName: bluetoothDeviceName ?? this.bluetoothDeviceName,
      wifiIp: wifiIp ?? this.wifiIp,
      wifiPort: wifiPort ?? this.wifiPort,
      storeName: storeName ?? this.storeName,
      storePhone: storePhone ?? this.storePhone,
      storeAddress: storeAddress ?? this.storeAddress,
    );
  }
}

class PrinterState {
  final PrinterSettings settings;
  final bool isConnected;
  final bool isLoading;
  final String? error;
  final List<PrinterDevice> scannedDevices;

  const PrinterState({
    this.settings = const PrinterSettings(),
    this.isConnected = false,
    this.isLoading = false,
    this.error,
    this.scannedDevices = const [],
  });

  PrinterState copyWith({
    PrinterSettings? settings,
    bool? isConnected,
    bool? isLoading,
    String? error,
    List<PrinterDevice>? scannedDevices,
  }) {
    return PrinterState(
      settings: settings ?? this.settings,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      scannedDevices: scannedDevices ?? this.scannedDevices,
    );
  }
}

class PrinterDevice {
  final String id;
  final String name;
  final String? address;

  const PrinterDevice({required this.id, required this.name, this.address});
}

class PrinterNotifier extends StateNotifier<PrinterState> {
  PrinterService? _service;

  PrinterNotifier() : super(const PrinterState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final type = prefs.getString('printer_type') == 'bluetooth'
        ? PrinterType.bluetooth
        : PrinterType.wifi;
    state = state.copyWith(
      settings: PrinterSettings(
        type: type,
        bluetoothDeviceId: prefs.getString('bt_device_id'),
        bluetoothDeviceName: prefs.getString('bt_device_name'),
        wifiIp: prefs.getString('wifi_ip') ?? '192.168.1.100',
        wifiPort: prefs.getInt('wifi_port') ?? 9100,
        storeName: prefs.getString('store_name') ?? 'فروشگاه هوشمند',
        storePhone: prefs.getString('store_phone') ?? '',
        storeAddress: prefs.getString('store_address') ?? '',
      ),
    );
  }

  Future<void> saveSettings(PrinterSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_type', settings.type.name);
    await prefs.setString('wifi_ip', settings.wifiIp);
    await prefs.setInt('wifi_port', settings.wifiPort);
    await prefs.setString('store_name', settings.storeName);
    await prefs.setString('store_phone', settings.storePhone);
    await prefs.setString('store_address', settings.storeAddress);
    if (settings.bluetoothDeviceId != null) {
      await prefs.setString('bt_device_id', settings.bluetoothDeviceId!);
      await prefs.setString('bt_device_name', settings.bluetoothDeviceName ?? '');
    }
    state = state.copyWith(settings: settings);
    // قطع ارتباط اگه تنظیمات تغییر کرد
    _service = null;
    state = state.copyWith(isConnected: false);
  }

  Future<bool> connect() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      _service = state.settings.type == PrinterType.bluetooth
          ? BluetoothPrinterService(
              deviceId: state.settings.bluetoothDeviceId ?? '',
              deviceName: state.settings.bluetoothDeviceName ?? '',
            )
          : WiFiPrinterService(
              ip: state.settings.wifiIp,
              port: state.settings.wifiPort,
            );
      final connected = await _service!.connect();
      state = state.copyWith(isConnected: connected, isLoading: false,
          error: connected ? null : 'اتصال به پرینتر ناموفق بود');
      return connected;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'خطا در اتصال: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _service?.disconnect();
    _service = null;
    state = state.copyWith(isConnected: false);
  }

  PrinterService? get service => _service;
}

final printerProvider = StateNotifierProvider<PrinterNotifier, PrinterState>((ref) {
  return PrinterNotifier();
});
