import 'package:drift/drift.dart';

import '../app_database.dart';

part 'mosque_dao.g.dart';

@DriftAccessor(tables: [Mosques])
class MosqueDao extends DatabaseAccessor<AppDatabase> with _$MosqueDaoMixin {
  MosqueDao(super.db);

  Stream<List<Mosque>> watchAll() =>
      (select(mosques)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<List<Mosque>> getAll() =>
      (select(mosques)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<Mosque?> getById(int id) =>
      (select(mosques)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertMosque(MosquesCompanion entry) =>
      into(mosques).insert(entry);

  Future<bool> updateMosque(MosquesCompanion entry) =>
      update(mosques).replace(entry);

  Future<int> deleteMosque(int id) =>
      (delete(mosques)..where((t) => t.id.equals(id))).go();
}
