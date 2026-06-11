import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/notification_service.dart';

/// وضعیت فرآیند همگام‌سازی
enum SyncStatus { idle, syncing, success, failed, offline }

/// اطلاعات وضعیت sync در هر لحظه
class SyncState {
  final SyncStatus status;
  final String? message;        // پیام قابل نمایش به کاربر
  final DateTime? lastSyncTime; // آخرین بار موفقیت‌آمیز

  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.lastSyncTime,
  });

  bool get isOnline => status != SyncStatus.offline;

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

/// مدیریت همگام‌سازی آفلاین/آنلاین
/// وقتی اینترنت برمی‌گردد → sync خودکار انجام می‌شود
class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier() : super(const SyncState()) {
    _listenConnectivity();
  }

  /// گوش دادن به تغییرات اتصال شبکه
  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);

      if (hasConnection && state.status == SyncStatus.offline) {
        // اینترنت برگشت → sync خودکار
        state = state.copyWith(status: SyncStatus.idle);
        sync();
      } else if (!hasConnection) {
        state = state.copyWith(
          status: SyncStatus.offline,
          message: 'اتصال اینترنت قطع است',
        );
      }
    });
  }

  /// شروع فرآیند همگام‌سازی با سرور
  Future<void> sync() async {
    if (state.status == SyncStatus.syncing) return; // از اجرای موازی جلوگیری
    state = state.copyWith(
      status: SyncStatus.syncing,
      message: 'در حال همگام‌سازی...',
    );
    try {
      // TODO: ارتباط واقعی با sync endpoint سرور
      await Future.delayed(const Duration(seconds: 2));
      state = state.copyWith(
        status: SyncStatus.success,
        message: 'همگام‌سازی موفق',
        lastSyncTime: DateTime.now(),
      );
      // اطلاع‌رسانی سیستمی فقط اگر اپ در پس‌زمینه باشد
      NotificationService.showSyncSuccess();
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.failed,
        message: 'همگام‌سازی ناموفق: $e',
      );
    }
  }

  /// بررسی وضعیت اتصال در لحظه
  Future<bool> checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}

/// Provider وضعیت sync
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier();
});

/// استریم وضعیت اتصال (true = آنلاین)
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});
