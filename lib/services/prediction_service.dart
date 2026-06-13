/// سرویس پیش‌بینی آفلاین — میانگین متحرک از SQLite محلی
/// بدون نیاز به اینترنت، همیشه در دسترس

import 'dart:convert';
import 'dart:math' as math;
import 'package:drift/drift.dart';
import '../data/local/database.dart';
import '../data/local/tables/prediction_cache_table.dart';
import '../domain/models/prediction.dart';

const _kDailyLimit = 3;

class PredictionService {
  final AppDatabase _db;

  PredictionService(this._db);

  // ─── محاسبه فروش روزانه از SQLite ─────────────────────────────

  Future<List<Map<String, dynamic>>> getDailySales({int days = 90}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final invoices = await _db.invoicesDao.getInvoicesByPeriod(since, DateTime.now());

    final Map<String, double> byDay = {};
    for (final inv in invoices) {
      final d = inv.createdAt;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      byDay[key] = (byDay[key] ?? 0) + inv.finalAmount;
    }

    return byDay.entries
        .map((e) => {'date': e.key, 'amount': e.value})
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  // ─── پیش‌بینی با میانگین متحرک ────────────────────────────────

  Future<SalesForecast> predictSalesOffline({int days = 30}) async {
    final salesData = await getDailySales(days: 90);
    final values = salesData.map((s) => (s['amount'] as num).toDouble()).toList();

    final window = values.isEmpty ? 1 : values.length.clamp(1, 7);
    final recent = values.reversed.take(window).toList();
    final avg = recent.isEmpty ? 0.0 : recent.fold(0.0, (a, b) => a + b) / recent.length;

    double std = 0;
    if (recent.length > 1) {
      final variance = recent.fold(0.0, (a, b) => a + (b - avg) * (b - avg)) / recent.length;
      std = math.sqrt(variance);
    }

    final predictions = <DailyPrediction>[];
    final base = DateTime.now();
    for (int i = 1; i <= days; i++) {
      final d = base.add(Duration(days: i));
      predictions.add(DailyPrediction(
        date: d,
        predictedAmount: avg,
        confidenceLow: (avg - std * 1.5).clamp(0, double.maxFinite),
        confidenceHigh: avg + std * 1.5,
      ));
    }

    final trend = _computeTrend(values);
    final (bestDay, worstDay) = _computeBestWorstDay(salesData);

    return SalesForecast(
      predictions: predictions,
      trend: trend,
      bestDay: bestDay,
      worstDay: worstDay,
      dataSource: 'moving_average',
      dataPoints: salesData.length,
    );
  }

  // ─── هشدار موجودی از SQLite ─────────────────────────────────

  Future<List<StockAlert>> getStockAlertsOffline() async {
    final products = await _db.productsDao.getLowStockProducts();
    if (products.isEmpty) return [];

    final since = DateTime.now().subtract(const Duration(days: 30));
    final invoices = await _db.invoicesDao.getInvoicesByPeriod(since, DateTime.now());

    final Map<int, double> productSales = {};
    for (final inv in invoices) {
      final items = await _db.invoicesDao.getInvoiceItems(inv.id);
      for (final item in items) {
        productSales[item.productId] = (productSales[item.productId] ?? 0) + item.quantity;
      }
    }

    final alerts = <StockAlert>[];
    for (final p in products) {
      final totalSold = productSales[p.id] ?? 0;
      final dailyAvg = totalSold / 30;
      if (dailyAvg <= 0) continue;

      final daysLeft = p.stockQuantity / dailyAvg;
      if (daysLeft > 7) continue;

      final urgency = daysLeft <= 2 ? 'critical' : (daysLeft <= 5 ? 'warning' : 'info');
      alerts.add(StockAlert(
        productId: p.id,
        productName: p.name,
        currentStock: p.stockQuantity.toDouble(),
        dailyAvgSales: dailyAvg,
        daysRemaining: daysLeft,
        urgency: urgency,
      ));
    }
    return alerts..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
  }

  // ─── پرفروش‌ترین محصولات از SQLite ──────────────────────────

  Future<List<TopProduct>> getTopProductsOffline() async {
    final now = DateTime.now();
    final thisWeekStart = now.subtract(const Duration(days: 7));
    final prevWeekStart = now.subtract(const Duration(days: 14));

    Future<Map<int, Map<String, dynamic>>> weekSales(
        DateTime start, DateTime end) async {
      final invs = await _db.invoicesDao.getInvoicesByPeriod(start, end);
      final Map<int, Map<String, dynamic>> sales = {};
      for (final inv in invs) {
        final items = await _db.invoicesDao.getInvoiceItems(inv.id);
        for (final item in items) {
          sales.putIfAbsent(
              item.productId, () => {'name': item.productName, 'qty': 0.0});
          sales[item.productId]!['qty'] =
              (sales[item.productId]!['qty'] as double) + item.quantity;
        }
      }
      return sales;
    }

    final current = await weekSales(thisWeekStart, now);
    final previous = await weekSales(prevWeekStart, thisWeekStart);

    if (current.isEmpty) return [];

    final sorted = current.entries.toList()
      ..sort((a, b) =>
          (b.value['qty'] as double).compareTo(a.value['qty'] as double));

    return sorted.take(5).map((e) {
      final prevQty = (previous[e.key]?['qty'] as double?) ?? 0;
      final currQty = e.value['qty'] as double;
      final trendPct = prevQty > 0 ? (currQty - prevQty) / prevQty * 100 : 100.0;
      final sign = trendPct >= 0 ? '+' : '';
      return TopProduct(
        productId: e.key,
        productName: e.value['name'] as String,
        predictedSales: currQty * 1.05,
        trendPercent: trendPct,
        trendLabel: '$sign${trendPct.toStringAsFixed(0)}٪ نسبت به هفته قبل',
      );
    }).toList();
  }

  // ─── cache AI در SQLite ──────────────────────────────────────

  Future<AiAnalysis?> getCachedAnalysis() async {
    final cached = await _db.predictionDao.getValidCache();
    if (cached == null) return null;
    final recs = (jsonDecode(cached.recommendationsJson) as List).cast<String>();
    return AiAnalysis(
      analysis: cached.analysisText,
      recommendations: recs,
      source: 'cache',
      generatedAt:
          '${cached.createdAt.year}/${cached.createdAt.month}/${cached.createdAt.day}',
      expiresAt:
          '${cached.expiresAt.year}/${cached.expiresAt.month}/${cached.expiresAt.day}',
      remainingRequests: await getRemainingRequests(),
    );
  }

  Future<void> saveAnalysisToCache(AiAnalysis analysis) async {
    final expires = DateTime.now().add(const Duration(hours: 24));
    await _db.predictionDao.saveCache(AiAnalysisCacheTableCompanion(
      analysisText: Value(analysis.analysis),
      recommendationsJson: Value(jsonEncode(analysis.recommendations)),
      salesHash: Value(_dailyKey()),
      createdAt: Value(DateTime.now()),
      expiresAt: Value(expires),
    ));
  }

  // ─── سهمیه ──────────────────────────────────────────────────

  Future<int> getRemainingRequests() async {
    final log = await _db.predictionDao.getTodayUsage();
    final used = log?.requestCount ?? 0;
    return (_kDailyLimit - used).clamp(0, _kDailyLimit);
  }

  Future<void> incrementLocalUsage() => _db.predictionDao.incrementUsage();

  // ─── helpers ────────────────────────────────────────────────

  String _dailyKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  String _computeTrend(List<double> values) {
    if (values.length < 4) return 'stable';
    final half = values.length ~/ 2;
    final firstAvg = values.take(half).fold(0.0, (a, b) => a + b) / half;
    final secondAvg =
        values.skip(half).fold(0.0, (a, b) => a + b) / (values.length - half);
    if (firstAvg == 0) return 'stable';
    final change = (secondAvg - firstAvg) / firstAvg;
    if (change > 0.05) return 'rising';
    if (change < -0.05) return 'falling';
    return 'stable';
  }

  static const _persianWeekdays = [
    'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه', 'یکشنبه',
  ];

  (String, String) _computeBestWorstDay(List<Map<String, dynamic>> data) {
    final Map<int, List<double>> byDay = {};
    for (final s in data) {
      final d = DateTime.parse(s['date'] as String);
      final idx = d.weekday % 7;
      byDay.putIfAbsent(idx, () => []);
      byDay[idx]!.add((s['amount'] as num).toDouble());
    }
    if (byDay.isEmpty) return ('—', '—');
    final avgs = byDay.map(
        (k, v) => MapEntry(k, v.fold(0.0, (a, b) => a + b) / v.length));
    final best = avgs.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final worst = avgs.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
    return (_persianWeekdays[best], _persianWeekdays[worst]);
  }
}
