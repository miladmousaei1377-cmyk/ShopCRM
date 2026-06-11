/// صفحه جزئیات مشتری
/// نمایش اطلاعات کامل، بدهی، سقف اعتبار و تاریخچه خرید
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_converter.dart';
import '../../../domain/models/customer.dart';
import '../../../domain/models/invoice.dart';
import '../../../domain/models/product.dart';
import '../../providers/cart_provider.dart';
import 'customers_screen.dart' show _CustomerFormDialog;

/// Provider برای دریافت اطلاعات یک مشتری خاص
final customerByIdProvider =
    FutureProvider.family<Customer?, int>((ref, id) {
  return ref.watch(customerRepositoryProvider).findById(id);
});

/// Provider برای دریافت فاکتورهای یک مشتری
final customerInvoicesProvider =
    FutureProvider.family<List<Invoice>, int>((ref, customerId) {
  return ref
      .watch(invoiceRepositoryProvider)
      .getCustomerInvoices(customerId);
});

class CustomerDetailScreen extends ConsumerWidget {
  /// شناسه مشتری — از مسیر ناوبری گرفته می‌شود
  final int customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // دریافت اطلاعات مشتری
    final customerAsync = ref.watch(customerByIdProvider(customerId));
    // دریافت فاکتورهای مشتری
    final invoicesAsync = ref.watch(customerInvoicesProvider(customerId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: customerAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('جزئیات مشتری')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('خطا')),
          body: Center(
            child: Text('خطا: $e',
                style: const TextStyle(fontFamily: 'Vazirmatn')),
          ),
        ),
        data: (customer) {
          if (customer == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('مشتری')),
              body: const Center(
                child: Text('مشتری یافت نشد',
                    style: TextStyle(fontFamily: 'Vazirmatn')),
              ),
            );
          }
          return _CustomerDetailBody(
            customer: customer,
            invoicesAsync: invoicesAsync,
            onCustomerUpdated: () {
              // بعد از ویرایش، provider را invalid کن تا دوباره بارگذاری شود
              ref.invalidate(customerByIdProvider(customerId));
            },
          );
        },
      ),
    );
  }
}

/// بدنه اصلی صفحه جزئیات مشتری
class _CustomerDetailBody extends ConsumerWidget {
  final Customer customer;
  final AsyncValue<List<Invoice>> invoicesAsync;
  final VoidCallback onCustomerUpdated;

  const _CustomerDetailBody({
    required this.customer,
    required this.invoicesAsync,
    required this.onCustomerUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // محاسبه میزان استفاده از اعتبار
    final creditUsagePercent = customer.creditLimit > 0
        ? (customer.totalDebt / customer.creditLimit).clamp(0.0, 1.0)
        : 0.0;
    final isOverCredit = customer.isOverCredit;

    return Scaffold(
      // ─── نوار بالا ─────────────────────────────────────────────
      appBar: AppBar(
        title: Text(
          customer.name,
          style: const TextStyle(
              fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700),
        ),
        actions: [
          // دکمه ویرایش اطلاعات مشتری
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: AppStrings.edit,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => _CustomerFormDialog(
                  customer: customer,
                  onSaved: onCustomerUpdated,
                ),
              );
            },
          ),
        ],
      ),

      // ─── محتوا ─────────────────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── کارت اطلاعات اصلی مشتری ─────────────────────────
            _buildInfoCard(context, creditUsagePercent, isOverCredit),
            const SizedBox(height: 16),

            // ─── کارت خلاصه مالی ────────────────────────────────
            _buildFinancialCard(context, isOverCredit),
            const SizedBox(height: 16),

            // ─── تاریخچه خرید ───────────────────────────────────
            _buildPurchaseHistory(context, ref),
          ],
        ),
      ),
    );
  }

  /// کارت اطلاعات اصلی مشتری: نام، تلفن، آدرس
  Widget _buildInfoCard(BuildContext context, double creditUsagePercent,
      bool isOverCredit) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // هدر کارت با آواتار
            Row(
              children: [
                // آواتار بزرگ مشتری
                CircleAvatar(
                  radius: 32,
                  backgroundColor: customer.hasDebt
                      ? AppColors.errorLight
                      : AppColors.infoLight,
                  child: Text(
                    customer.name.isNotEmpty
                        ? customer.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: customer.hasDebt
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (customer.phone != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              customer.phone!,
                              style: const TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // آدرس مشتری
            if (customer.address != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      customer.address!,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // نوار پیشرفت استفاده از اعتبار
            if (customer.creditLimit > 0) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'مصرف اعتبار',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${(creditUsagePercent * 100).toStringAsFixed(0)}٪',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOverCredit
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // نوار پیشرفت رنگی
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: creditUsagePercent,
                  backgroundColor: AppColors.background,
                  color: isOverCredit ? AppColors.error : AppColors.success,
                  minHeight: 8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// کارت خلاصه مالی: بدهی کل و سقف اعتبار
  Widget _buildFinancialCard(BuildContext context, bool isOverCredit) {
    return Row(
      children: [
        // کارت بدهی کل
        Expanded(
          child: Card(
            elevation: 0,
            color: customer.hasDebt ? AppColors.errorLight : AppColors.successLight,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.totalDebt,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      color: customer.hasDebt
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.format(customer.totalDebt),
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: customer.hasDebt
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // کارت سقف اعتبار
        Expanded(
          child: Card(
            elevation: 0,
            color: AppColors.infoLight,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppStrings.creditLimit,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    customer.creditLimit > 0
                        ? CurrencyFormatter.format(customer.creditLimit)
                        : 'بدون سقف',
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// بخش تاریخچه خرید — لیست فاکتورها
  Widget _buildPurchaseHistory(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // عنوان بخش
        Row(
          children: [
            const Icon(Icons.history_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              AppStrings.purchaseHistory,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // لیست فاکتورهای مشتری
        invoicesAsync.when(
          loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )),
          error: (e, _) => Center(
            child: Text(
              'خطا در بارگذاری فاکتورها: $e',
              style: const TextStyle(
                  fontFamily: 'Vazirmatn', color: AppColors.error),
            ),
          ),
          data: (invoices) {
            if (invoices.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'هیچ خریدی ثبت نشده',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 14,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              );
            }
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: invoices.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (ctx, index) {
                  final invoice = invoices[index];
                  return _InvoiceHistoryTile(
                    invoice: invoice,
                    onTap: () =>
                        context.go('/invoices/${invoice.id}'),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── ردیف فاکتور در تاریخچه خرید ────────────────────────────────────────────

class _InvoiceHistoryTile extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;

  const _InvoiceHistoryTile({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // رنگ روش پرداخت
    Color paymentColor;
    switch (invoice.paymentMethod) {
      case PaymentMethod.cash:
        paymentColor = AppColors.success;
        break;
      case PaymentMethod.card:
        paymentColor = AppColors.primary;
        break;
      case PaymentMethod.credit:
        paymentColor = AppColors.warning;
        break;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // آیکون روش پرداخت
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: paymentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                invoice.paymentMethod == PaymentMethod.cash
                    ? Icons.payments_outlined
                    : invoice.paymentMethod == PaymentMethod.card
                        ? Icons.credit_card_outlined
                        : Icons.account_balance_wallet_outlined,
                color: paymentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // اطلاعات فاکتور
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateConverter.toShamsiLong(invoice.createdAt),
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // مبلغ نهایی
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(invoice.finalAmount),
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: paymentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    invoice.paymentMethod.label,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 10,
                      color: paymentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left,
                color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}
