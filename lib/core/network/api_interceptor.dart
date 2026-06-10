import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiInterceptor extends Interceptor {
  final Dio dio;
  final FlutterSecureStorage secureStorage;
  bool _isRefreshing = false;

  ApiInterceptor({required this.dio, required this.secureStorage});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.read(key: ApiConstants.tokenKey);
    if (token != null) {
      options.headers[ApiConstants.authHeader] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // اگه ۴۰۱ دریافت کردیم، تلاش برای رفرش توکن
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await secureStorage.read(
          key: ApiConstants.refreshTokenKey,
        );
        if (refreshToken != null) {
          final response = await dio.post(
            ApiConstants.refreshToken,
            data: {'refresh_token': refreshToken},
          );
          final newToken = response.data['access_token'] as String;
          await secureStorage.write(key: ApiConstants.tokenKey, value: newToken);

          // ارسال مجدد درخواست اصلی
          err.requestOptions.headers[ApiConstants.authHeader] = 'Bearer $newToken';
          final retryResponse = await dio.fetch(err.requestOptions);
          handler.resolve(retryResponse);
          return;
        }
      } catch (_) {
        // رفرش توکن ناموفق → خروج
        await _clearTokens();
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }

  Future<void> _clearTokens() async {
    await secureStorage.delete(key: ApiConstants.tokenKey);
    await secureStorage.delete(key: ApiConstants.refreshTokenKey);
  }

  static String parseErrorMessage(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return 'اتصال به سرور با خطا مواجه شد. لطفاً اتصال اینترنت را بررسی کنید.';
    }
    if (err.type == DioExceptionType.connectionError) {
      return 'ارتباط با سرور برقرار نشد';
    }
    final statusCode = err.response?.statusCode;
    switch (statusCode) {
      case 400: return 'درخواست نامعتبر';
      case 401: return 'لطفاً دوباره وارد شوید';
      case 403: return 'دسترسی مجاز نیست';
      case 404: return 'مورد یافت نشد';
      case 422: return _parseValidationErrors(err.response?.data);
      case 500: return 'خطای داخلی سرور';
      default: return 'خطا در ارتباط با سرور';
    }
  }

  static String _parseValidationErrors(dynamic data) {
    if (data is Map && data.containsKey('detail')) {
      final detail = data['detail'];
      if (detail is List && detail.isNotEmpty) {
        return detail.first['msg']?.toString() ?? 'خطا در اعتبارسنجی';
      }
      return detail.toString();
    }
    return 'خطا در اعتبارسنجی داده‌ها';
  }
}
