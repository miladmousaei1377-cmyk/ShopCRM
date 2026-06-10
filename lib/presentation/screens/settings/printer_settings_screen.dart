import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../providers/printer_provider.dart';
import '../../widgets/common/loading_overlay.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  final _storePhoneCtrl = TextEditingController();
  final _storeAddressCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _initialized = false;

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _storeNameCtrl.dispose();
    _storePhoneCtrl.dispose();
    _storeAddressCtrl.dispose();
    super.dispose();
  }

  void _initControllers(PrinterSettings s) {
    if (_initialized) return;
    _ipCtrl.text = s.wifiIp;
    _portCtrl.text = s.wifiPort.toString();
    _storeNameCtrl.text = s.storeName;
    _storePhoneCtrl.text = s.storePhone;
    _storeAddressCtrl.text = s.storeAddress;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printerProvider);
    _initControllers(state.settings);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.printerSettings)),
        body: LoadingOverlay(
          isLoading: state.isLoading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // انتخاب نوع پرینتر
                  _Section(
                    title: 'نوع پرینتر',
                    child: Row(
                      children: PrinterType.values.map((type) {
                        final selected = state.settings.type == type;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              ref.read(printerProvider.notifier).saveSettings(
                                state.settings.copyWith(type: type),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primary.withOpacity(0.1) : AppColors.background,
                                border: Border.all(
                                  color: selected ? AppColors.primary : AppColors.border,
                                  width: selected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    type == PrinterType.bluetooth ? Icons.bluetooth : Icons.wifi,
                                    color: selected ? AppColors.primary : AppColors.textSecondary,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    type == PrinterType.bluetooth ? AppStrings.bluetoothPrinter : AppStrings.wifiPrinter,
                                    style: TextStyle(
                                      fontFamily: 'Vazirmatn',
                                      fontSize: 13,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                      color: selected ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // تنظیمات وای‌فای
                  if (state.settings.type == PrinterType.wifi)
                    _Section(
                      title: AppStrings.wifiPrinter,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _ipCtrl,
                                  textDirection: TextDirection.ltr,
                                  decoration: const InputDecoration(
                                    labelText: AppStrings.printerIp,
                                    hintText: '192.168.1.100',
                                  ),
                                  validator: Validators.ipAddress,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _portCtrl,
                                  textDirection: TextDirection.ltr,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: AppStrings.printerPort,
                                    hintText: '9100',
                                  ),
                                  validator: Validators.port,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.network_ping, size: 18),
                                  label: const Text(AppStrings.testConnection,
                                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
                                  onPressed: _testWifiConnection,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.print, size: 18),
                                  label: const Text(AppStrings.testPrint,
                                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
                                  onPressed: _testPrint,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // تنظیمات بلوتوث
                  if (state.settings.type == PrinterType.bluetooth)
                    _Section(
                      title: AppStrings.bluetoothPrinter,
                      child: Column(
                        children: [
                          if (state.settings.bluetoothDeviceName != null)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.bluetooth_connected, color: AppColors.primary),
                              title: Text(
                                state.settings.bluetoothDeviceName!,
                                style: const TextStyle(fontFamily: 'Vazirmatn'),
                              ),
                              trailing: state.isConnected
                                  ? const Chip(
                                      label: Text('متصل',
                                          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11)),
                                      backgroundColor: AppColors.successLight,
                                    )
                                  : null,
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.search, size: 18),
                              label: const Text(AppStrings.scanDevices,
                                  style: TextStyle(fontFamily: 'Vazirmatn')),
                              onPressed: _scanBluetooth,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // اطلاعات فروشگاه
                  _Section(
                    title: 'اطلاعات فروشگاه (روی رسید)',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _storeNameCtrl,
                          decoration: const InputDecoration(labelText: 'نام فروشگاه'),
                          validator: (v) => Validators.required(v, fieldName: 'نام فروشگاه'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _storePhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: AppStrings.phone),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _storeAddressCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: AppStrings.address),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // پیام خطا
                  if (state.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.error!,
                        style: const TextStyle(fontFamily: 'Vazirmatn', color: AppColors.error, fontSize: 13),
                      ),
                    ),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _save,
                      child: const Text(AppStrings.save,
                          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _testWifiConnection() async {
    if (!_formKey.currentState!.validate()) return;
    await _saveSettings();
    final ok = await ref.read(printerProvider.notifier).connect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          ok ? AppStrings.printerConnected : AppStrings.printerNotFound,
          style: const TextStyle(fontFamily: 'Vazirmatn'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ));
    }
  }

  Future<void> _testPrint() async {
    // TODO: ارسال print test
  }

  void _scanBluetooth() {
    // TODO: scan BT devices
  }

  Future<void> _saveSettings() async {
    final current = ref.read(printerProvider).settings;
    await ref.read(printerProvider.notifier).saveSettings(
      current.copyWith(
        wifiIp: _ipCtrl.text.trim(),
        wifiPort: int.tryParse(_portCtrl.text) ?? 9100,
        storeName: _storeNameCtrl.text.trim(),
        storePhone: _storePhoneCtrl.text.trim(),
        storeAddress: _storeAddressCtrl.text.trim(),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _saveSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(AppStrings.operationSuccess,
            style: TextStyle(fontFamily: 'Vazirmatn')),
        backgroundColor: AppColors.success,
      ));
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
