import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/local/database.dart';
import '../../domain/models/prediction.dart';
import '../../services/prediction_service.dart';
import '../../core/network/dio_client.dart';
import 'product_provider.dart';

// ─── Provider پایه ────────────────────────────────────────────────────────────

final predictionServiceProvider = Provider<PredictionService>((ref) {
  return PredictionService(ref.watch(databaseProvider));
});

// ─── بررسی اتصال اینترنت ─────────────────────────────────────────────────────

final _isOnlineProvider = FutureProvider<bool>((ref) async {
  final result = await Connectivity().checkConnectivity();
  return !result.contains(ConnectivityResult.none);
});

// ─── پیش‌بینی فروش ───────────────────────────────────────────────────────────

final salesForecastProvider = FutureProvider.family<SalesForecast, int>((ref, days) async {
  final svc = ref.watch(predictionServiceProvider);
  final isOnline = await ref.watch(_isOnlineProvider.future);

  if (isOnline) {
    try {
      final dio = await DioClient.getInstance();
      final resp = await dio.get(
        '/prediction/daily',
        queryParameters: {'days': days},
      );
      return SalesForecast.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {}
  }

  // fallback آفلاین
  return svc.predictSalesOffline(days: days);
});

// ─── هشدار موجودی ────────────────────────────────────────────────────────────

final stockAlertsProvider = FutureProvider<List<StockAlert>>((ref) async {
  final svc = ref.watch(predictionServiceProvider);
  final isOnline = await ref.watch(_isOnlineProvider.future);

  if (isOnline) {
    try {
      final dio = await DioClient.getInstance();
      final resp = await dio.get('/prediction/stock-alert');
      final data = (resp.data['alerts'] as List)
          .map((e) => StockAlert.fromJson(e as Map<String, dynamic>))
          .toList();
      return data;
    } catch (_) {}
  }

  return svc.getStockAlertsOffline();
});

// ─── پرفروش‌ترین محصولات ─────────────────────────────────────────────────────

final topProductsProvider = FutureProvider<List<TopProduct>>((ref) async {
  final svc = ref.watch(predictionServiceProvider);
  final isOnline = await ref.watch(_isOnlineProvider.future);

  if (isOnline) {
    try {
      final dio = await DioClient.getInstance();
      final resp = await dio.get('/prediction/top-products');
      if (resp.data['data_available'] == true) {
        return (resp.data['next_week_tops'] as List)
            .map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {}
  }

  return svc.getTopProductsOffline();
});

// ─── تحلیل هوشمند Claude ─────────────────────────────────────────────────────

final aiAnalysisProvider = FutureProvider<AiAnalysis?>((ref) async {
  final svc = ref.watch(predictionServiceProvider);
  final isOnline = await ref.watch(_isOnlineProvider.future);

  if (isOnline) {
    try {
      final dio = await DioClient.getInstance();
      final resp = await dio.post(
        '/prediction/ai-analysis',
        data: {'period': 'week', 'force': false},
      );
      final analysis = AiAnalysis.fromJson(resp.data as Map<String, dynamic>);
      await svc.saveAnalysisToCache(analysis);
      return analysis;
    } catch (_) {}
  }

  // fallback cache آفلاین
  return svc.getCachedAnalysis();
});

// ─── وضعیت سهمیه ─────────────────────────────────────────────────────────────

final aiStatusProvider = FutureProvider<AiStatus>((ref) async {
  final svc = ref.watch(predictionServiceProvider);
  final isOnline = await ref.watch(_isOnlineProvider.future);
  final remaining = await svc.getRemainingRequests();

  if (isOnline) {
    try {
      final dio = await DioClient.getInstance();
      final resp = await dio.get('/prediction/ai-status');
      return AiStatus.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) {}
  }

  return AiStatus(
    dailyLimit: 3,
    usedToday: 3 - remaining,
    remaining: remaining,
    cacheValid: false,
  );
});

// ─── درخواست تحلیل جدید (دستی) ──────────────────────────────────────────────

class AiRefreshNotifier extends StateNotifier<AsyncValue<AiAnalysis?>> {
  final PredictionService _svc;
  final Ref _ref;

  AiRefreshNotifier(this._svc, this._ref) : super(const AsyncValue.data(null));

  Future<void> refresh({bool force = false}) async {
    state = const AsyncValue.loading();
    try {
      final isOnline = await Connectivity().checkConnectivity()
          .then((r) => !r.contains(ConnectivityResult.none));

      if (!isOnline) {
        final cached = await _svc.getCachedAnalysis();
        state = AsyncValue.data(cached);
        return;
      }

      final dio = await DioClient.getInstance();
      final resp = await dio.post(
        '/prediction/ai-analysis',
        data: {'period': 'week', 'force': force},
      );
      final analysis = AiAnalysis.fromJson(resp.data as Map<String, dynamic>);
      await _svc.saveAnalysisToCache(analysis);
      if (force) await _svc.incrementLocalUsage();

      state = AsyncValue.data(analysis);
      _ref.invalidate(aiStatusProvider);
      _ref.invalidate(aiAnalysisProvider);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        state = AsyncValue.error(
          'سهمیه روزانه تمام شد. فردا دوباره امتحان کنید.',
          StackTrace.current,
        );
      } else {
        final cached = await _svc.getCachedAnalysis();
        state = AsyncValue.data(cached);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final aiRefreshProvider =
    StateNotifierProvider<AiRefreshNotifier, AsyncValue<AiAnalysis?>>((ref) {
  return AiRefreshNotifier(ref.watch(predictionServiceProvider), ref);
});

// ─── خلاصه برای داشبورد ──────────────────────────────────────────────────────

class DashboardPrediction {
  final double tomorrowPrediction;
  final String trend;
  final int stockAlertCount;

  const DashboardPrediction({
    required this.tomorrowPrediction,
    required this.trend,
    required this.stockAlertCount,
  });
}

final dashboardPredictionProvider = FutureProvider<DashboardPrediction>((ref) async {
  final forecast = await ref.watch(salesForecastProvider(7).future);
  final alerts = await ref.watch(stockAlertsProvider.future);

  final tomorrow = forecast.predictions.isNotEmpty
      ? forecast.predictions.first.predictedAmount
      : 0.0;

  return DashboardPrediction(
    tomorrowPrediction: tomorrow,
    trend: forecast.trend,
    stockAlertCount: alerts.where((a) => a.urgency == 'critical').length,
  );
});
