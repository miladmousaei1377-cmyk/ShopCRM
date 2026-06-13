import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/prediction_cache_table.dart';

part 'prediction_dao.g.dart';

@DriftAccessor(tables: [AiAnalysisCacheTable, AiUsageLogTable])
class PredictionDao extends DatabaseAccessor<AppDatabase>
    with _$PredictionDaoMixin {
  PredictionDao(super.db);

  // ─── cache تحلیل AI ──────────────────────────────────────────

  Future<AiAnalysisCacheTableData?> getValidCache() {
    final now = DateTime.now();
    return (select(aiAnalysisCacheTable)
          ..where((t) => t.expiresAt.isBiggerThanValue(now))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> saveCache(AiAnalysisCacheTableCompanion cache) async {
    // حذف cache قدیمی قبل از ذخیره
    await delete(aiAnalysisCacheTable).go();
    await into(aiAnalysisCacheTable).insert(cache);
  }

  Future<void> clearCache() => delete(aiAnalysisCacheTable).go();

  // ─── لاگ مصرف سهمیه ─────────────────────────────────────────

  Future<AiUsageLogTableData?> getTodayUsage() {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return (select(aiUsageLogTable)..where((t) => t.date.equals(dateStr)))
        .getSingleOrNull();
  }

  Future<void> incrementUsage() async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final existing = await getTodayUsage();
    if (existing != null) {
      await (update(aiUsageLogTable)
            ..where((t) => t.date.equals(dateStr)))
          .write(AiUsageLogTableCompanion(
            requestCount: Value(existing.requestCount + 1),
          ));
    } else {
      await into(aiUsageLogTable).insert(
        AiUsageLogTableCompanion(
          date: Value(dateStr),
          requestCount: const Value(1),
        ),
      );
    }
  }
}
