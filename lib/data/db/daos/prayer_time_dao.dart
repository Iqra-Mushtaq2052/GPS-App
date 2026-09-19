import 'package:drift/drift.dart';
import '../app_database.dart';
part 'prayer_time_dao.g.dart';

@DriftAccessor(tables: [LocalPrayerTimes])
class LocalPrayerTimesDao extends DatabaseAccessor<AppDatabase> with _$LocalPrayerTimesDaoMixin {
  LocalPrayerTimesDao(super.db);

  Future<LocalPrayerTime?> getByMosqueId(int mosqueId) => 
    (select(localPrayerTimes)..where((t) => t.mosqueId.equals(mosqueId))).getSingleOrNull();

  Future<void> upsert(LocalPrayerTimesCompanion entry) =>
    into(localPrayerTimes).insertOnConflictUpdate(entry);
  
  Future<void> deleteByMosqueId(int mosqueId) =>
    (delete(localPrayerTimes)..where((t) => t.mosqueId.equals(mosqueId))).go();
}
