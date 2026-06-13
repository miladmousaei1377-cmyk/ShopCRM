class ApiConstants {
  ApiConstants._();

  // آدرس پایه سرور - از env یا shared_preferences خوانده می‌شود
  static const String defaultBaseUrl = 'http://localhost:8000/api';
  static const String apiVersion = 'v1';

  // تایم‌اوت (میلی‌ثانیه)
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 30000;
  static const int sendTimeout = 30000;

  // هدرها
  static const String authHeader = 'Authorization';
  static const String contentType = 'Content-Type';
  static const String applicationJson = 'application/json';

  // مسیرهای API
  static const String login = '/auth/login';
  static const String refreshToken = '/auth/refresh';

  static const String products = '/products/';
  static const String productById = '/products/{id}';
  static const String productByBarcode = '/products/barcode/{code}';

  static const String invoices = '/invoices/';
  static const String invoiceById = '/invoices/{id}';

  static const String customers = '/customers/';
  static const String customerById = '/customers/{id}';
  static const String customerHistory = '/customers/{id}/history';

  static const String syncPush = '/sync/push';
  static const String syncPull = '/sync/pull';

  static const String reportDaily = '/reports/daily';
  static const String reportPeriod = '/reports/period';
  static const String reportTopProducts = '/reports/top-products';
  static const String dashboardSummary = '/dashboard/summary';

  // پیش‌بینی فروش
  static const String predictionDaily = '/prediction/daily';
  static const String predictionStockAlert = '/prediction/stock-alert';
  static const String predictionTopProducts = '/prediction/top-products';
  static const String predictionAiAnalysis = '/prediction/ai-analysis';
  static const String predictionAiStatus = '/prediction/ai-status';

  // کلیدهای ذخیره‌سازی
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String baseUrlKey = 'base_url';
  static const String userKey = 'current_user';

  // صفحه‌بندی
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
}
