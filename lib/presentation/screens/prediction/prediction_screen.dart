import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/prediction.dart';
import '../../providers/prediction_provider.dart';

class PredictionScreen extends ConsumerStatefulWidget {
  const PredictionScreen({super.key});

  @override
  ConsumerState<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends ConsumerState<PredictionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _forecastDays = 7;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _forecastDays = _tabController.index == 0 ? 7 : 30);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('پیش‌بینی فروش',
              style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700)),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(salesForecastProvider(_forecastDays));
            ref.invalidate(stockAlertsProvider);
            ref.invalidate(topProductsProvider);
            ref.invalidate(aiAnalysisProvider);
            ref.invalidate(aiStatusProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // ── بخش ۱: کارت تحلیل هوشمند ──
                _AiAnalysisCard(),
                const SizedBox(height: 12),

                // ── بخش ۲: نمودار پیش‌بینی فروش ──
                _ForecastChartCard(
                  tabController: _tabController,
                  forecastDays: _forecastDays,
                ),
                const SizedBox(height: 12),

                // ── بخش ۳: هشدار موجودی ──
                _StockAlertsCard(),
                const SizedBox(height: 12),

                // ── بخش ۴: پرفروش‌های هفته آینده ──
                _TopProductsCard(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// بخش ۱ — کارت تحلیل هوشمند Claude
// ═══════════════════════════════════════════════════════════

class _AiAnalysisCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(aiAnalysisProvider);
    final statusAsync = ref.watch(aiStatusProvider);
    final refreshState = ref.watch(aiRefreshProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF6A1B9A)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'دستیار هوشمند',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                statusAsync.when(
                  loading: () => const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  error: (_, __) => _onlineBadge(false),
                  data: (s) => _onlineBadge(s.cacheValid || s.remaining > 0),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // متن تحلیل
            _buildAnalysisContent(context, ref, analysisAsync, refreshState),

            const SizedBox(height: 12),

            // footer
            Row(
              children: [
                analysisAsync.when(
                  data: (a) => a != null
                      ? Text(
                          'به‌روزرسانی: ${a.generatedAt}',
                          style: const TextStyle(
                              fontFamily: 'Vazirmatn', fontSize: 11, color: Colors.white70),
                        )
                      : const SizedBox(),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
                const Spacer(),
                statusAsync.when(
                  data: (status) => _RefreshButton(status: status),
                  loading: () => const SizedBox(),
                  error: (_, __) => _RefreshButton(
                      status: const AiStatus(
                          dailyLimit: 3, usedToday: 0, remaining: 3, cacheValid: false)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisContent(BuildContext context, WidgetRef ref,
      AsyncValue<AiAnalysis?> analysisAsync, AsyncValue<AiAnalysis?> refreshState) {
    // اگه refresh در حال اجرا باشد
    if (refreshState is AsyncLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final analysis = refreshState.value ?? analysisAsync.value;

    if (analysis == null) {
      return const Text(
        'برای دریافت تحلیل هوشمند، دکمه به‌روزرسانی را بزنید.',
        style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: Colors.white70),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          analysis.analysis,
          style: const TextStyle(
              fontFamily: 'Vazirmatn', fontSize: 13, color: Colors.white, height: 1.6),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: analysis.recommendations
              .map((r) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Text(r,
                        style: const TextStyle(
                            fontFamily: 'Vazirmatn', fontSize: 11, color: Colors.white)),
                  ))
              .toList(),
        ),
        if (analysis.source == 'cache')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('آفلاین — تحلیل ذخیره‌شده',
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: Colors.white70)),
            ),
          ),
      ],
    );
  }

  Widget _onlineBadge(bool online) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: online ? Colors.green.shade400 : Colors.grey.shade500,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        online ? 'آنلاین' : 'آفلاین',
        style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: Colors.white),
      ),
    );
  }
}

class _RefreshButton extends ConsumerWidget {
  final AiStatus status;
  const _RefreshButton({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canRefresh = status.remaining > 0;
    return GestureDetector(
      onTap: canRefresh
          ? () => ref.read(aiRefreshProvider.notifier).refresh(force: true)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: canRefresh ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30),
            ),
            child: Text(
              canRefresh
                  ? 'به‌روزرسانی (${status.remaining} باقی)'
                  : 'سهمیه امروز تمام شد',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 11,
                color: canRefresh ? Colors.white : Colors.white54,
              ),
            ),
          ),
          if (!canRefresh)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text('فردا ۳ بار دیگر',
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, color: Colors.white38)),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// بخش ۲ — نمودار پیش‌بینی فروش
// ═══════════════════════════════════════════════════════════

class _ForecastChartCard extends ConsumerWidget {
  final TabController tabController;
  final int forecastDays;
  const _ForecastChartCard({required this.tabController, required this.forecastDays});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(salesForecastProvider(forecastDays));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('نمودار پیش‌بینی فروش',
                      style: TextStyle(
                          fontFamily: 'Vazirmatn', fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                forecastAsync.when(
                  data: (f) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      f.dataSource == 'prophet' ? 'Prophet' : 'میانگین متحرک',
                      style: const TextStyle(
                          fontFamily: 'Vazirmatn', fontSize: 10, color: AppColors.primary),
                    ),
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // TabBar
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: tabController,
                tabs: const [Tab(text: '۷ روز'), Tab(text: '۳۰ روز')],
                labelStyle: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
                unselectedLabelStyle:
                    const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                dividerColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 16),

            // نمودار
            SizedBox(
              height: 200,
              child: forecastAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text('خطا در بارگذاری', style: const TextStyle(fontFamily: 'Vazirmatn')),
                ),
                data: (forecast) {
                  if (forecast.predictions.isEmpty) {
                    return const Center(
                      child: Text('داده‌ای موجود نیست',
                          style: TextStyle(fontFamily: 'Vazirmatn', color: AppColors.textHint)),
                    );
                  }
                  return _buildChart(forecast);
                },
              ),
            ),

            const SizedBox(height: 12),

            // خلاصه آماری
            forecastAsync.when(
              data: (f) => _buildSummary(f),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(SalesForecast forecast) {
    final spots = forecast.predictions
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.predictedAmount / 1000))
        .toList();

    final confidenceSpotsLow = forecast.predictions
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.confidenceLow / 1000))
        .toList();

    final confidenceSpotsHigh = forecast.predictions
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.confidenceHigh / 1000))
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: AppColors.divider,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, meta) => Text(
                '${v.toStringAsFixed(0)}k',
                style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 9,
                    color: AppColors.textSecondary),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (forecast.predictions.length / 4).ceilToDouble(),
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= forecast.predictions.length) {
                  return const SizedBox();
                }
                final d = forecast.predictions[idx].date;
                return Text('${d.month}/${d.day}',
                    style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 9,
                        color: AppColors.textSecondary));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // confidence band — high
          LineChartBarData(
            spots: confidenceSpotsHigh,
            isCurved: true,
            color: AppColors.primary.withOpacity(0.1),
            barWidth: 0,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withOpacity(0.08),
            ),
          ),
          // خط اصلی پیش‌بینی
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.primary,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(SalesForecast f) {
    final trendIcon = f.trend == 'rising'
        ? Icons.trending_up
        : f.trend == 'falling'
            ? Icons.trending_down
            : Icons.trending_flat;
    final trendColor = f.trend == 'rising'
        ? AppColors.success
        : f.trend == 'falling'
            ? AppColors.error
            : AppColors.textSecondary;

    return Row(
      children: [
        Expanded(
          child: _SummaryChip(
            icon: Icons.calendar_today_outlined,
            label: 'بهترین روز',
            value: f.bestDay,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            icon: trendIcon,
            label: 'روند',
            value: f.trend == 'rising'
                ? 'صعودی'
                : f.trend == 'falling'
                    ? 'نزولی'
                    : 'ثابت',
            color: trendColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            icon: Icons.data_usage_outlined,
            label: 'داده',
            value: '${f.dataPoints} روز',
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SummaryChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 9,
                  color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11,
                  fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// بخش ۳ — هشدار موجودی
// ═══════════════════════════════════════════════════════════

class _StockAlertsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(stockAlertsProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 20),
                SizedBox(width: 8),
                Text('هشدار موجودی',
                    style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            alertsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('خطا در بارگذاری',
                  style: TextStyle(fontFamily: 'Vazirmatn')),
              data: (alerts) {
                if (alerts.isEmpty) {
                  return const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                      SizedBox(width: 8),
                      Text('همه محصولات موجودی کافی دارند',
                          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13,
                              color: AppColors.success)),
                    ],
                  );
                }
                return Column(
                  children: alerts.map((a) => _StockAlertTile(alert: a)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StockAlertTile extends StatelessWidget {
  final StockAlert alert;
  const _StockAlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = alert.urgency == 'critical'
        ? AppColors.error
        : alert.urgency == 'warning'
            ? AppColors.warning
            : Colors.amber;

    final daysProgress =
        (alert.daysRemaining / 7).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(alert.productName,
                    style: const TextStyle(
                        fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alert.urgency == 'critical'
                      ? 'بحرانی'
                      : alert.urgency == 'warning'
                          ? 'هشدار'
                          : 'اطلاع',
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10,
                      fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: daysProgress,
              backgroundColor: color.withOpacity(0.1),
              color: color,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${alert.daysRemaining.toStringAsFixed(1)} روز دیگر تمام می‌شود — موجودی: ${alert.currentStock.toStringAsFixed(0)} عدد',
            style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// بخش ۴ — پرفروش‌های هفته آینده
// ═══════════════════════════════════════════════════════════

class _TopProductsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topsAsync = ref.watch(topProductsProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star_outline, color: AppColors.secondary, size: 20),
                SizedBox(width: 8),
                Text('پرفروش‌های هفته آینده',
                    style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            topsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('خطا در بارگذاری',
                  style: TextStyle(fontFamily: 'Vazirmatn')),
              data: (tops) {
                if (tops.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'برای پیش‌بینی به حداقل ۷ روز داده فروش نیاز است',
                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13,
                          color: AppColors.textSecondary),
                    ),
                  );
                }
                return SizedBox(
                  height: 130,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: tops.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _TopProductCard(product: tops[i]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopProductCard extends StatelessWidget {
  final TopProduct product;
  const _TopProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final isUp = product.trendPercent >= 0;
    final trendColor = isUp ? AppColors.success : AppColors.error;
    final trendIcon = isUp ? Icons.trending_up : Icons.trending_down;

    return Container(
      width: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            product.productName,
            style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 11,
                fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(trendIcon, color: trendColor, size: 13),
              const SizedBox(width: 2),
              Text(
                product.trendLabel.split(' ').first,
                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10,
                    color: trendColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
