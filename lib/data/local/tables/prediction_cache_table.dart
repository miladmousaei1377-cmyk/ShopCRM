import 'package:drift/drift.dart';

/// cache تحلیل Claude AI در SQLite (برای نمایش آفلاین)
class AiAnalysisCacheTable extends Table {
  @override
  String get tableName => 'ai_analysis_cache';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get analysisText => text()();
  TextColumn get recommendationsJson => text()(); // JSON array
  TextColumn get salesHash => text()();           // MD5 برای تشخیص تغییر
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
}

/// لاگ مصرف سهمیه روزانه
class AiUsageLogTable extends Table {
  @override
  String get tableName => 'ai_usage_log';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get requestCount => integer().withDefault(const Constant(0))();
}
