import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

/// Interceptor اصلی Dio
/// وظایف:
///   ۱. افزودن توکن JWT به هدر هر درخواست
///   ۲. رفرش خودکار توکن وقتی ۴۰۱ می‌گیریم
///   ۳. تبدیل کدهای خطا به پیام فارسی
class ApiInterceptor extends Interceptor {
  final Dio dio;
  final FlutterSecureStorage secureStorage;
  bool _isRefreshing = false; // جلوگیری از رفرش موازی

  ApiInterceptor({required this.dio, required this.secureStorage});

  /// افزودن Bearer token به هدر هر درخواست خروجی
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

  /// مدیریت خطاهای پاسخ
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // خطای ۴۰۱ = توکن منقضی شده → تلاش برای رفرش
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken =
            await secureStorage.read(key: ApiConstants.refreshTokenKey);

        if (refreshToken != null) {
          // درخواست رفرش توکن
          final response = await dio.post(
            ApiConstants.refreshToken,
            data: {'refresh_token': refreshToken},
          );
          final newToken = response.data['access_token'] as String;

          // ذخیره توکن جدید
          await secureStorage.write(
            key: ApiConstants.tokenKey,
            value: newToken,
          );

          // ارسال مجدد درخواست اصلی با توکن جدید
          err.requestOptions.headers[ApiConstants.authHeader] = 'Bearer $newToken';
          final retryResponse = await dio.fetch(err.requestOptions);
          handler.resolve(retryResponse);
          return;
        }
      } catch (_) {
        // رفرش هم شکست خورد → خروج از حساب
        await _clearTokens();
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }

  /// پاک کردن توکن‌ها (برای logout اضطراری)
  Future<void> _clearTokens() async {
    await secureStorage.delete(key: ApiConstants.tokenKey);
    await secureStorage.delete(key: ApiConstants.refreshTokenKey);
  }

  /// تبدیل DioException به پیام فارسی قابل نمایش
  static String parseErrorMessage(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return 'اتصال به سرور با تایم‌اوت مواجه شد. لطفاً اینترنت را بررسی کنید.';
    }
    if (err.type == DioExceptionType.connectionError) {
      return 'ارتباط با سرور برقرار نشد';
    }
    switch (err.response?.statusCode) {
      case 400: return 'درخواست نامعتبر';
      case 401: return 'لطفاً دوباره وارد شوید';
      case 403: return 'دسترسی مجاز نیست';
      case 404: return 'مورد یافت نشد';
      case 422: return _parseValidationErrors(err.response?.data);
      case 500: return 'خطای داخلی سرور';
      default:  return 'خطا در ارتباط با سرور';
    }
  }

  /// پارس خطاهای validation از FastAPI (422)
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
