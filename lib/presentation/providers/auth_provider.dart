import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';

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
    final token = await _secureStorage.read(key: ApiConstants.tokenKey);
    if (token != null) {
      state = state.copyWith(isLoggedIn: true);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // TODO: ارسال درخواست به سرور
      // فعلاً mock login
      if (username.isNotEmpty && password.isNotEmpty) {
        await _secureStorage.write(
          key: ApiConstants.tokenKey,
          value: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConstants.userKey, username);

        state = state.copyWith(isLoggedIn: true, isLoading: false, username: username);
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'نام کاربری یا رمز عبور اشتباه است');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'خطا در ورود به سیستم');
      return false;
    }
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
