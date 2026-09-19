// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prayer_time_dao.dart';

// ignore_for_file: type=lint
mixin _$LocalPrayerTimesDaoMixin on DatabaseAccessor<AppDatabase> {
  $MosquesTable get mosques => attachedDatabase.mosques;
  $LocalPrayerTimesTable get localPrayerTimes =>
      attachedDatabase.localPrayerTimes;
  LocalPrayerTimesDaoManager get managers => LocalPrayerTimesDaoManager(this);
}

class LocalPrayerTimesDaoManager {
  final _$LocalPrayerTimesDaoMixin _db;
  LocalPrayerTimesDaoManager(this._db);
  $$MosquesTableTableManager get mosques =>
      $$MosquesTableTableManager(_db.attachedDatabase, _db.mosques);
  $$LocalPrayerTimesTableTableManager get localPrayerTimes =>
      $$LocalPrayerTimesTableTableManager(
        _db.attachedDatabase,
        _db.localPrayerTimes,
      );
}
