import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum SyncStatus { idle, syncing, success, failed, offline }

class SyncState {
  final SyncStatus status;
  final String? message;
  final DateTime? lastSyncTime;

  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.lastSyncTime,
  });

  bool get isOnline => status != SyncStatus.offline;

  SyncState copyWith({SyncStatus? status, String? message, DateTime? lastSyncTime}) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier() : super(const SyncState()) {
    _listenConnectivity();
  }

  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection && state.status == SyncStatus.offline) {
        state = state.copyWith(status: SyncStatus.idle);
        sync(); // اتصال برقرار شد، sync خودکار
      } else if (!hasConnection) {
        state = state.copyWith(status: SyncStatus.offline, message: 'اتصال اینترنت قطع است');
      }
    });
  }

  Future<void> sync() async {
    if (state.status == SyncStatus.syncing) return;
    state = state.copyWith(status: SyncStatus.syncing, message: 'در حال همگام‌سازی...');
    try {
      // TODO: sync واقعی با سرور
      await Future.delayed(const Duration(seconds: 2));
      state = state.copyWith(
        status: SyncStatus.success,
        message: 'همگام‌سازی موفق',
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(status: SyncStatus.failed, message: 'همگام‌سازی ناموفق: $e');
    }
  }

  Future<bool> checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier();
});

final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});
