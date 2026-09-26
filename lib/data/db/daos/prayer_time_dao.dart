import 'package:drift/drift.dart';
import '../app_database.dart';
part 'prayer_time_dao.g.dart';

@DriftAccessor(tables: [LocalPrayerTimes])
class LocalPrayerTimesDao extends DatabaseAccessor<AppDatabase> with _$LocalPrayerTimesDaoMixin {
  LocalPrayerTimesDao(super.db);

  /// Latest row for a mosque. (Older builds could create duplicate rows, so
  /// this never uses getSingle — it takes the newest one.)
  Future<LocalPrayerTime?> getByMosqueId(int mosqueId) =>
      (select(localPrayerTimes)
            ..where((t) => t.mosqueId.equals(mosqueId))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt), (t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingleOrNull();

  /// One row per mosque: replaces whatever rows exist for [entry.mosqueId].
  Future<void> upsert(LocalPrayerTimesCompanion entry) {
    return transaction(() async {
      await (delete(localPrayerTimes)
            ..where((t) => t.mosqueId.equals(entry.mosqueId.value)))
          .go();
      await into(localPrayerTimes).insert(entry.copyWith(id: const Value.absent()));
    });
  }

  Future<void> deleteByMosqueId(int mosqueId) =>
      (delete(localPrayerTimes)..where((t) => t.mosqueId.equals(mosqueId))).go();
}
