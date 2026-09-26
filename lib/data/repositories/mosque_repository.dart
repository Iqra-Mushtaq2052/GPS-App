import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/daos/mosque_dao.dart';

/// Thin wrapper around [MosqueDao] so the rest of the app depends on a
/// simple repository interface instead of Drift types directly.
class MosqueRepository {
  MosqueRepository(this._dao);

  final MosqueDao _dao;

  Stream<List<Mosque>> watchAll() => _dao.watchAll();

  Future<List<Mosque>> getAll() => _dao.getAll();

  Future<Mosque?> getById(int id) => _dao.getById(id);

  Future<Mosque?> getBySupabaseId(String supabaseId) => _dao.getBySupabaseId(supabaseId);

  Future<int> add({
    required String name,
    required double latitude,
    required double longitude,
    int radiusMeters = 150,
    String? supabaseId,
    String? shareCode,
  }) {
    return _dao.insertMosque(
      MosquesCompanion.insert(
        name: name,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: Value(radiusMeters),
        supabaseId: Value(supabaseId),
        shareCode: Value(shareCode),
      ),
    );
  }

  /// Inserts a cloud mosque locally, or refreshes the existing copy
  /// (name / location / radius) while keeping the user's on/off switch.
  /// Returns the local id.
  Future<int> upsertCloud({
    required String supabaseId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? shareCode,
  }) async {
    final existing = await _dao.getBySupabaseId(supabaseId);
    if (existing == null) {
      return add(
        name: name,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        supabaseId: supabaseId,
        shareCode: shareCode,
      );
    }
    final changed = existing.name != name ||
        existing.latitude != latitude ||
        existing.longitude != longitude ||
        existing.radiusMeters != radiusMeters ||
        (shareCode != null && existing.shareCode != shareCode);
    if (changed) {
      await update(existing.copyWith(
        name: name,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        shareCode: Value(shareCode ?? existing.shareCode),
      ));
    }
    return existing.id;
  }

  Future<void> update(Mosque mosque) => _dao.updateMosque(mosque.toCompanion(true));

  Future<void> delete(int id) => _dao.deleteMosque(id);
}
