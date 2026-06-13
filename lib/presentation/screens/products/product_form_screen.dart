import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/product.dart';
import '../../providers/product_provider.dart';
import '../../widgets/barcode/barcode_scanner_widget.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../widgets/common/currency_input.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final int? productId;
  final String? initialBarcode;

  const ProductFormScreen({super.key, this.productId, this.initialBarcode});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _sellPriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _minStockCtrl = TextEditingController(text: '5');

  double _purchasePrice = 0;
  double _sellPrice = 0;
  bool _isLoading = false;
  Product? _existingProduct;

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) {
      _barcodeCtrl.text = widget.initialBarcode!;
    }
    if (widget.productId != null) {
      _loadProduct();
    }
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    final product = await ref.read(productRepositoryProvider).findById(widget.productId!);
    if (product != null && mounted) {
      _existingProduct = product;
      _nameCtrl.text = product.name;
      _barcodeCtrl.text = product.barcode ?? '';
      _purchasePriceCtrl.text = CurrencyFormatter.formatNumber(product.purchasePrice);
      _sellPriceCtrl.text = CurrencyFormatter.formatNumber(product.sellPrice);
      _stockCtrl.text = product.stockQuantity.toString();
      _minStockCtrl.text = product.minStockAlert.toString();
      _purchasePrice = product.purchasePrice;
      _sellPrice = product.sellPrice;
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _sellPriceCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final product = Product(
      id: _existingProduct?.id ?? 0,
      name: _nameCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      purchasePrice: _purchasePrice,
      sellPrice: _sellPrice,
      stockQuantity: int.tryParse(CurrencyFormatter.toEnglishNumber(_stockCtrl.text)) ?? 0,
      minStockAlert: int.tryParse(CurrencyFormatter.toEnglishNumber(_minStockCtrl.text)) ?? 5,
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );

    final success = await ref.read(productFormProvider.notifier).save(product);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('محصول با موفقیت ذخیره شد',
            style: TextStyle(fontFamily: 'Vazirmatn')),
        backgroundColor: AppColors.success,
      ));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(productFormProvider);
    final isEdit = widget.productId != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? AppStrings.editProduct : AppStrings.addProduct),
          actions: [
            if (isEdit)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _confirmDelete,
              ),
          ],
        ),
        body: LoadingOverlay(
          isLoading: _isLoading || formState.isLoading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // نام محصول
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: AppStrings.productName,
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    validator: (v) => Validators.required(v, fieldName: 'نام محصول'),
                  ),
                  const SizedBox(height: 16),

                  // بارکد
                  TextFormField(
                    controller: _barcodeCtrl,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: AppStrings.barcode,
                      prefixIcon: const Icon(Icons.qr_code),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scanBarcode,
                      ),
                    ),
                    validator: Validators.barcode,
                  ),
                  const SizedBox(height: 16),

                  // قیمت‌ها
                  Row(
                    children: [
                      Expanded(
                        child: CurrencyInput(
                          controller: _purchasePriceCtrl,
                          label: AppStrings.purchasePrice,
                          onChanged: (v) => _purchasePrice = v,
                          validator: Validators.price,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CurrencyInput(
                          controller: _sellPriceCtrl,
                          label: AppStrings.sellPrice,
                          onChanged: (v) => _sellPrice = v,
                          validator: Validators.price,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // سود نمایشی
                  if (_sellPrice > 0 && _purchasePrice > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'سود: ${CurrencyFormatter.format(_sellPrice - _purchasePrice)} '
                        '(${CurrencyFormatter.formatPercent(_sellPrice > 0 ? (_sellPrice - _purchasePrice) / _sellPrice * 100 : 0)})',
                        style: const TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 13,
                          color: AppColors.success,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),

                  // موجودی
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: AppStrings.stockQuantity,
                            suffixText: 'عدد',
                          ),
                          validator: Validators.quantity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _minStockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: AppStrings.minStockAlert,
                            suffixText: 'عدد',
                          ),
                          validator: Validators.quantity,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // پیام خطا
                  if (formState.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        formState.error!,
                        style: const TextStyle(
                          fontFamily: 'Vazirmatn',
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: formState.isLoading ? null : _save,
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

  void _scanBarcode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BarcodeScannerWidget(
            onDetected: (barcode) async {
              setState(() => _barcodeCtrl.text = barcode);

              // جستجو در پایگاه داده محلی
              final product = await ref.read(productRepositoryProvider).findByBarcode(barcode);
              if (product != null && mounted) {
                setState(() {
                  _nameCtrl.text = product.name;
                  _purchasePriceCtrl.text = CurrencyFormatter.formatNumber(product.purchasePrice);
                  _sellPriceCtrl.text = CurrencyFormatter.formatNumber(product.sellPrice);
                  _stockCtrl.text = product.stockQuantity.toString();
                  _minStockCtrl.text = product.minStockAlert.toString();
                  _purchasePrice = product.purchasePrice;
                  _sellPrice = product.sellPrice;
                  _existingProduct = product;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('محصول "${product.name}" پیدا شد',
                          style: const TextStyle(fontFamily: 'Vazirmatn')),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
                return;
              }

              // جستجوی آنلاین در Open Food Facts
              if (!mounted) return;
              setState(() => _isLoading = true);
              try {
                final response = await Dio().get<Map<String, dynamic>>(
                  'https://world.openfoodfacts.org/api/v2/product/$barcode',
                  queryParameters: {'fields': 'product_name,product_name_fa'},
                  options: Options(receiveTimeout: const Duration(seconds: 8)),
                );
                final data = response.data;
                if (data != null && data['status'] == 1) {
                  final product = data['product'] as Map<String, dynamic>?;
                  final name = (product?['product_name_fa'] as String?)?.trim().isNotEmpty == true
                      ? product!['product_name_fa'] as String
                      : (product?['product_name'] as String?)?.trim();
                  if (name != null && name.isNotEmpty && mounted) {
                    setState(() => _nameCtrl.text = name);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('نام محصول: $name',
                            style: const TextStyle(fontFamily: 'Vazirmatn')),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    return;
                  }
                }
              } catch (_) {
                // network error — fall through to "not found"
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('نام محصول یافت نشد — لطفاً دستی وارد کنید',
                        style: TextStyle(fontFamily: 'Vazirmatn')),
                    backgroundColor: AppColors.warning,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(AppStrings.deleteProduct),
          content: const Text(AppStrings.deleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppStrings.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(context);
                final ok = await ref.read(productFormProvider.notifier)
                    .delete(widget.productId!);
                if (ok && mounted) context.pop();
              },
              child: const Text(AppStrings.delete),
            ),
          ],
        ),
      ),
    );
  }
}
