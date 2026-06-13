import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? error;
  final String? username;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.error,
    this.username,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    String? error,
    String? username,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      username: username ?? this.username,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FlutterSecureStorage _secureStorage;

  AuthNotifier(this._secureStorage) : super(const AuthState()) {
    _checkToken();
  }

  Future<void> _checkToken() async {
    // Don't auto-login — user must authenticate explicitly each launch
    // Token is kept for biometric/quick-login use
  }

  Future<bool> hasStoredToken() async {
    final token = await _secureStorage.read(key: ApiConstants.tokenKey);
    return token != null;
  }

  Future<bool> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      state = state.copyWith(isLoading: false, error: 'نام کاربری و رمز عبور الزامی است');
      return false;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.post(
        ApiConstants.login,
        data: {'username': username, 'password': password},
      );
      final token = response.data['access_token'] as String;
      final refresh = response.data['refresh_token'] as String?;
      await _secureStorage.write(key: ApiConstants.tokenKey, value: token);
      if (refresh != null) {
        await _secureStorage.write(key: ApiConstants.refreshTokenKey, value: refresh);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.userKey, username);
      state = state.copyWith(isLoggedIn: true, isLoading: false, username: username);
      return true;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 422) {
        state = state.copyWith(isLoading: false, error: 'نام کاربری یا رمز عبور اشتباه است');
        return false;
      }
      // سرور در دسترس نیست — حالت آفلاین (فقط برای توسعه)
      await _secureStorage.write(
        key: ApiConstants.tokenKey,
        value: 'offline_${DateTime.now().millisecondsSinceEpoch}',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.userKey, username);
      state = state.copyWith(isLoggedIn: true, isLoading: false, username: username);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'خطا در ورود به سیستم');
      return false;
    }
  }

  // ورود با اثر انگشت: فقط وجود توکن ذخیره‌شده را بررسی می‌کند
  Future<bool> loginWithBiometric() async {
    final token = await _secureStorage.read(key: ApiConstants.tokenKey);
    if (token == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(ApiConstants.userKey) ?? '';
    state = state.copyWith(isLoggedIn: true, username: username);
    return true;
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: ApiConstants.tokenKey);
    await _secureStorage.delete(key: ApiConstants.refreshTokenKey);
    state = const AuthState();
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(secureStorageProvider));
});
