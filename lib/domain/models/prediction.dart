/// مدل‌های داده برای ماژول پیش‌بینی فروش

class DailyPrediction {
  final DateTime date;
  final double predictedAmount;
  final double confidenceLow;
  final double confidenceHigh;

  const DailyPrediction({
    required this.date,
    required this.predictedAmount,
    required this.confidenceLow,
    required this.confidenceHigh,
  });

  factory DailyPrediction.fromJson(Map<String, dynamic> j) => DailyPrediction(
        date: DateTime.parse(j['date'] as String),
        predictedAmount: (j['predicted_amount'] as num).toDouble(),
        confidenceLow: (j['confidence_low'] as num).toDouble(),
        confidenceHigh: (j['confidence_high'] as num).toDouble(),
      );
}

class SalesForecast {
  final List<DailyPrediction> predictions;
  final String trend;       // rising | falling | stable
  final String bestDay;
  final String worstDay;
  final String dataSource;  // prophet | moving_average
  final int dataPoints;

  const SalesForecast({
    required this.predictions,
    required this.trend,
    required this.bestDay,
    required this.worstDay,
    required this.dataSource,
    required this.dataPoints,
  });

  factory SalesForecast.fromJson(Map<String, dynamic> j) => SalesForecast(
        predictions: (j['predictions'] as List)
            .map((e) => DailyPrediction.fromJson(e as Map<String, dynamic>))
            .toList(),
        trend: j['trend'] as String? ?? 'stable',
        bestDay: j['best_day_of_week'] as String? ?? '—',
        worstDay: j['worst_day_of_week'] as String? ?? '—',
        dataSource: j['data_source'] as String? ?? 'moving_average',
        dataPoints: j['data_points'] as int? ?? 0,
      );
}

class StockAlert {
  final int productId;
  final String productName;
  final double currentStock;
  final double dailyAvgSales;
  final double daysRemaining;
  final String urgency; // critical | warning | info

  const StockAlert({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.dailyAvgSales,
    required this.daysRemaining,
    required this.urgency,
  });

  factory StockAlert.fromJson(Map<String, dynamic> j) => StockAlert(
        productId: j['product_id'] as int,
        productName: j['product_name'] as String,
        currentStock: (j['current_stock'] as num).toDouble(),
        dailyAvgSales: (j['daily_avg_sales'] as num).toDouble(),
        daysRemaining: (j['days_remaining'] as num).toDouble(),
        urgency: j['urgency'] as String,
      );
}

class TopProduct {
  final int productId;
  final String productName;
  final double predictedSales;
  final double trendPercent;
  final String trendLabel;

  const TopProduct({
    required this.productId,
    required this.productName,
    required this.predictedSales,
    required this.trendPercent,
    required this.trendLabel,
  });

  factory TopProduct.fromJson(Map<String, dynamic> j) => TopProduct(
        productId: j['product_id'] as int,
        productName: j['product_name'] as String,
        predictedSales: (j['predicted_sales'] as num).toDouble(),
        trendPercent: (j['trend_percent'] as num).toDouble(),
        trendLabel: j['trend_label'] as String,
      );
}

class AiAnalysis {
  final String analysis;
  final List<String> recommendations;
  final String source;       // cache | fresh
  final String generatedAt;
  final String expiresAt;
  final int remainingRequests;

  const AiAnalysis({
    required this.analysis,
    required this.recommendations,
    required this.source,
    required this.generatedAt,
    required this.expiresAt,
    required this.remainingRequests,
  });

  factory AiAnalysis.fromJson(Map<String, dynamic> j) => AiAnalysis(
        analysis: j['analysis'] as String,
        recommendations:
            (j['recommendations'] as List).map((e) => e as String).toList(),
        source: j['source'] as String? ?? 'fresh',
        generatedAt: j['generated_at'] as String? ?? '',
        expiresAt: j['expires_at'] as String? ?? '',
        remainingRequests: j['remaining_manual_requests'] as int? ?? 3,
      );
}

class AiStatus {
  final int dailyLimit;
  final int usedToday;
  final int remaining;
  final String? lastAnalysisAt;
  final bool cacheValid;
  final String? cacheExpiresAt;

  const AiStatus({
    required this.dailyLimit,
    required this.usedToday,
    required this.remaining,
    this.lastAnalysisAt,
    required this.cacheValid,
    this.cacheExpiresAt,
  });

  factory AiStatus.fromJson(Map<String, dynamic> j) => AiStatus(
        dailyLimit: j['daily_limit'] as int? ?? 3,
        usedToday: j['used_today'] as int? ?? 0,
        remaining: j['remaining'] as int? ?? 3,
        lastAnalysisAt: j['last_analysis_at'] as String?,
        cacheValid: j['cache_valid'] as bool? ?? false,
        cacheExpiresAt: j['cache_expires_at'] as String?,
      );
}
