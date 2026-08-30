// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mosque_dao.dart';

// ignore_for_file: type=lint
mixin _$MosqueDaoMixin on DatabaseAccessor<AppDatabase> {
  $MosquesTable get mosques => attachedDatabase.mosques;
  MosqueDaoManager get managers => MosqueDaoManager(this);
}

class MosqueDaoManager {
  final _$MosqueDaoMixin _db;
  MosqueDaoManager(this._db);
  $$MosquesTableTableManager get mosques =>
      $$MosquesTableTableManager(_db.attachedDatabase, _db.mosques);
}
