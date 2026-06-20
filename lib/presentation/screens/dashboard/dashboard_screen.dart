import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_converter.dart';
import '../../../data/repositories/customer_repository.dart';
import '../../providers/product_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/report_provider.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../widgets/charts/sales_chart.dart';
import '../../../domain/models/invoice.dart';
import '../../providers/prediction_provider.dart';
import '../../providers/theme_provider.dart';

final totalDebtProvider = FutureProvider<double>((ref) {
  return CustomerRepository(ref.watch(databaseProvider)).getTotalDebt();
});

final lowStockCountProvider = FutureProvider<int>((ref) async {
  final products = await ref.watch(lowStockProductsProvider.future);
  return products.length;
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySales = ref.watch(todaySalesTotalProvider);
    final productCount = ref.watch(productsStreamProvider);
    final lowStockCount = ref.watch(lowStockCountProvider);
    final totalDebt = ref.watch(totalDebtProvider);
    final recentInvoices = ref.watch(recentInvoicesProvider);
    final lowStockProducts = ref.watch(lowStockProductsProvider);
    final weeklySales = ref.watch(weeklySalesProvider);
    final syncState = ref.watch(syncProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.dashboard),
          actions: [
            IconButton(
              icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
              tooltip: isDark ? 'حالت روشن' : 'حالت تاریک',
            ),
            // وضعیت sync
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _SyncStatusChip(syncState: syncState),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(syncProvider.notifier).sync(),
              tooltip: 'همگام‌سازی',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(todaySalesTotalProvider);
            ref.invalidate(weeklySalesProvider);
            ref.invalidate(recentInvoicesProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // تاریخ امروز
                Text(
                  DateConverter.toShamsiLong(DateTime.now()),
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // کارت‌های آمار — ۲ ستون روی موبایل، ۴ ستون روی دسکتاپ
                LayoutBuilder(builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return GridView.count(
                  crossAxisCount: isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 2.2 : 1.25,
                  children: [
                    StatCard(
                      title: AppStrings.todaySales,
                      value: todaySales.when(
                        data: (v) => CurrencyFormatter.format(v),
                        loading: () => '...',
                        error: (_, __) => '---',
                      ),
                      icon: Icons.point_of_sale,
                      color: AppColors.cardSales,
                      onTap: () => context.go('/invoices'),
                    ),
                    StatCard(
                      title: AppStrings.totalInventory,
                      value: productCount.when(
                        data: (products) => '${CurrencyFormatter.formatNumber(products.length)} محصول',
                        loading: () => '...',
                        error: (_, __) => '---',
                      ),
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.cardInventory,
                      onTap: () => context.go('/products'),
                    ),
                    StatCard(
                      title: AppStrings.lowStockAlert,
                      value: lowStockCount.when(
                        data: (v) => '$v محصول',
                        loading: () => '...',
                        error: (_, __) => '---',
                      ),
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.cardAlert,
                      subtitle: lowStockCount.value != null && lowStockCount.value! > 0
                          ? 'نیاز به تأمین' : null,
                      onTap: () => context.go('/inventory'),
                    ),
                    StatCard(
                      title: AppStrings.debtors,
                      value: totalDebt.when(
                        data: (v) => CurrencyFormatter.format(v),
                        loading: () => '...',
                        error: (_, __) => '---',
                      ),
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.cardDebt,
                      onTap: () => context.go('/customers'),
                    ),
                  ],
                );
                }),
                const SizedBox(height: 16),

                // کارت خلاصه پیش‌بینی
                _PredictionSummaryCard(),
                const SizedBox(height: 24),

                // نمودار فروش هفتگی
                _SectionHeader(title: AppStrings.weeklySalesChart),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: weeklySales.when(
                      data: (data) => SalesChart(dailySales: data),
                      loading: () => const SizedBox(
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => const SizedBox(
                        height: 100,
                        child: Center(child: Text('خطا در بارگذاری نمودار',
                            style: TextStyle(fontFamily: 'Vazirmatn'))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // آخرین فاکتورها
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionHeader(title: AppStrings.recentInvoices),
                    TextButton(
                      onPressed: () => context.go('/invoices'),
                      child: const Text('مشاهده همه',
                          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                recentInvoices.when(
                  data: (invoices) => invoices.isEmpty
                      ? _EmptyState(
                          icon: Icons.receipt_long_outlined,
                          message: 'هنوز فاکتوری ثبت نشده',
                        )
                      : Column(
                          children: invoices.map((inv) => _InvoiceTile(invoice: inv)).toList(),
                        ),
                  loading: () => const ShimmerList(itemCount: 3, itemHeight: 64),
                  error: (_, __) => _ErrorWidget(
                    onRetry: () => ref.invalidate(recentInvoicesProvider),
                  ),
                ),
                const SizedBox(height: 24),

                // محصولات کم موجود
                _SectionHeader(title: AppStrings.lowStockProducts),
                const SizedBox(height: 8),
                lowStockProducts.when(
                  data: (products) => products.isEmpty
                      ? _EmptyState(
                          icon: Icons.check_circle_outline,
                          message: 'همه محصولات موجودی کافی دارند',
                        )
                      : Column(
                          children: products.take(5).map((p) => ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.warningLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.warning_amber,
                                  color: AppColors.warning, size: 20),
                            ),
                            title: Text(p.name,
                                style: const TextStyle(
                                    fontFamily: 'Vazirmatn', fontSize: 14)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.errorLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${p.stockQuantity} عدد',
                                style: const TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 12,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )).toList(),
                        ),
                  loading: () => const ShimmerList(itemCount: 3, itemHeight: 64),
                  error: (_, __) => const SizedBox(),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/invoice/new'),
          icon: const Icon(Icons.add),
          label: const Text(AppStrings.newInvoice,
              style: TextStyle(fontFamily: 'Vazirmatn')),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Vazirmatn',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt_outlined,
              color: AppColors.primary, size: 22),
        ),
        title: Text(
          invoice.invoiceNumber,
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          DateConverter.toShamsiWithTime(invoice.createdAt),
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Text(
          CurrencyFormatter.format(invoice.finalAmount),
          style: const TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        onTap: () => context.go('/invoices/${invoice.id}'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textHint),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorWidget({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text('خطا در بارگذاری',
              style: TextStyle(fontFamily: 'Vazirmatn', color: AppColors.error)),
          TextButton(
            onPressed: onRetry,
            child: const Text(AppStrings.retry,
                style: TextStyle(fontFamily: 'Vazirmatn')),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusChip extends StatelessWidget {
  final dynamic syncState;
  const _SyncStatusChip({required this.syncState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: syncState.isOnline ? Colors.greenAccent : Colors.orange,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            syncState.isOnline ? AppStrings.online : AppStrings.offline,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionSummaryCard extends ConsumerWidget {
  const _PredictionSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predictionAsync = ref.watch(dashboardPredictionProvider);
    return predictionAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (pred) => GestureDetector(
        onTap: () => context.go('/prediction'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF6A1B9A)],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'پیش‌بینی فردا',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(pred.tomorrowPrediction),
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (pred.stockAlertCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pred.stockAlertCount} هشدار',
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                pred.trend == 'up'
                    ? Icons.trending_up
                    : pred.trend == 'down'
                        ? Icons.trending_down
                        : Icons.trending_flat,
                color: pred.trend == 'up'
                    ? Colors.greenAccent
                    : pred.trend == 'down'
                        ? Colors.redAccent
                        : Colors.white70,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
