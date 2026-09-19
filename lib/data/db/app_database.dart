import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'daos/mosque_dao.dart';
import 'daos/prayer_time_dao.dart';

part 'app_database.g.dart';

/// A masjid the user has saved, along with the geofence radius (in meters)
/// that should trigger the auto-silent behaviour when entered/exited.
class Mosques extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  IntColumn get radiusMeters => integer().withDefault(const Constant(40))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get supabaseId => text().nullable()();
  TextColumn get shareCode => text().nullable()();
}

class LocalPrayerTimes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mosqueId => integer().references(Mosques, #id)();
  TextColumn get fajr => text().withDefault(const Constant('05:00'))();
  TextColumn get dhuhr => text().withDefault(const Constant('13:00'))();
  TextColumn get asr => text().withDefault(const Constant('17:00'))();
  TextColumn get maghrib => text().withDefault(const Constant('18:30'))();
  TextColumn get isha => text().withDefault(const Constant('20:00'))();
  TextColumn get cloudMosqueId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Mosques, LocalPrayerTimes], daos: [MosqueDao, LocalPrayerTimesDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(mosques, mosques.supabaseId);
        await migrator.addColumn(mosques, mosques.shareCode);
        await migrator.createTable(localPrayerTimes);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'gps_app_db',
      native: DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
