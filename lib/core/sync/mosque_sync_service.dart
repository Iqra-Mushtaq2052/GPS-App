import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/mosque_repository.dart';
import '../notifications/notification_service.dart';
import '../supabase/supabase_config.dart';
import '../supabase/supabase_service.dart';

/// Keeps every downloaded / managed mosque connected to the cloud:
///
/// * caches jamaat times + announcements on the phone (works offline),
/// * listens to Supabase Realtime while the app is open, so a time change or
///   a new announcement by the imam shows up instantly,
/// * mirrors imam edits (name / radius / location) and removals into the
///   local mosque list that drives the auto-vibrate geofence.
class MosqueSyncService extends ChangeNotifier {
  // Named parameters may not start with an underscore, so the private
  // fields are assigned in the initializer list.
  // ignore_for_file: prefer_initializing_formals
  MosqueSyncService({
    required MosqueRepository repository,
    required AppDatabase database,
    required SupabaseService api,
    required NotificationService notifications,
  })  : _repository = repository,
        _database = database,
        _api = api,
        _notifications = notifications;

  final MosqueRepository _repository;
  final AppDatabase _database;
  final SupabaseService _api;
  final NotificationService _notifications;

  /// Called whenever the local mosque list was changed by the sync (so the
  /// proximity engine / native service can reload geofences).
  Future<void> Function()? onLocalMosquesChanged;

  static const _prefsTimes = 'sync_prayer_times_v1';
  static const _prefsAnnouncements = 'sync_announcements_v1';
  static const _prefsLastSync = 'sync_last_sync_v1';

  StreamSubscription<List<Mosque>>? _repoSub;
  RealtimeChannel? _channel;
  bool _started = false;
  bool _refreshing = false;
  bool _refreshQueued = false;

  Set<String> _ids = {};
  Map<String, Mosque> _localByCloudId = {};
  Map<String, CloudPrayerTimes> _times = {};
  List<CloudAnnouncement> _announcements = [];
  List<ManagedMosque> _managed = [];
  bool _live = false;
  DateTime? _lastSync;
  String? _lastError;

  // ── Public state ─────────────────────────────────────────────────────

  bool get isLive => _live;
  DateTime? get lastSync => _lastSync;
  String? get lastError => _lastError;
  List<ManagedMosque> get managedMosques => List.unmodifiable(_managed);

  CloudPrayerTimes? timesFor(String? cloudMosqueId) =>
      cloudMosqueId == null ? null : _times[cloudMosqueId];

  /// Newest-first announcements for the given mosques (all if null).
  List<CloudAnnouncement> announcementsFor([Iterable<String>? cloudIds]) {
    if (cloudIds == null) return List.unmodifiable(_announcements);
    final set = cloudIds.toSet();
    return _announcements.where((a) => set.contains(a.mosqueId)).toList();
  }

  String mosqueName(String cloudMosqueId) {
    final local = _localByCloudId[cloudMosqueId];
    if (local != null) return local.name;
    for (final m in _managed) {
      if (m.id == cloudMosqueId) return m.name;
    }
    return 'Masjid';
  }

  /// Local mosques that are connected to the cloud, sorted by name.
  List<Mosque> get connectedMosques =>
      _localByCloudId.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  bool isDownloaded(String cloudMosqueId) => _localByCloudId.containsKey(cloudMosqueId);

  Mosque? localFor(String? cloudMosqueId) =>
      cloudMosqueId == null ? null : _localByCloudId[cloudMosqueId];

  bool isManaged(String? cloudMosqueId) =>
      cloudMosqueId != null && _managed.any((m) => m.id == cloudMosqueId);

  ManagedMosque? managedFor(String? cloudMosqueId) {
    for (final m in _managed) {
      if (m.id == cloudMosqueId) return m;
    }
    return null;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _loadCache();
    _repoSub = _repository.watchAll().listen(_onLocalMosques);
  }

  @override
  void dispose() {
    _repoSub?.cancel();
    _removeChannel();
    super.dispose();
  }

  void _onLocalMosques(List<Mosque> list) {
    _localByCloudId = {
      for (final m in list)
        if (m.supabaseId != null && m.supabaseId!.isNotEmpty) m.supabaseId!: m,
    };
    final ids = _localByCloudId.keys.toSet();
    if (!setEquals(ids, _ids)) {
      _ids = ids;
      _resubscribe();
      unawaited(refresh());
    }
    notifyListeners();
  }

  // ── Download / remove (Masjid Store) ─────────────────────────────────

  /// Adds a store mosque to this phone and connects it (follow + live sync).
  Future<void> downloadMosque(CloudMosque mosque) async {
    await _repository.upsertCloud(
      supabaseId: mosque.id,
      name: mosque.name,
      latitude: mosque.latitude,
      longitude: mosque.longitude,
      radiusMeters: mosque.radiusMeters,
      shareCode: mosque.shareCode,
    );
    try {
      await _api.followMosque(mosque.id);
    } catch (e) {
      debugPrint('follow failed: $e');
    }
    await onLocalMosquesChanged?.call();
  }

  /// Removes a downloaded mosque from this phone (and unfollows it).
  Future<void> removeDownloaded(Mosque mosque) async {
    final cloudId = mosque.supabaseId;
    if (cloudId != null) {
      try {
        await _api.unfollowMosque(cloudId);
      } catch (_) {}
    }
    await _removeLocal(mosque);
    await onLocalMosquesChanged?.call();
  }

  Future<void> _removeLocal(Mosque mosque) async {
    await _database.localPrayerTimesDao.deleteByMosqueId(mosque.id);
    await _repository.delete(mosque.id);
    final cloudId = mosque.supabaseId;
    if (cloudId != null) {
      _times.remove(cloudId);
      _announcements.removeWhere((a) => a.mosqueId == cloudId);
      await _saveCache();
    }
  }

  // ── Managed mosques (imam / committee) ───────────────────────────────

  /// Loads the mosques this account manages and makes sure each one is also
  /// on the phone (so the imam gets the same live view + auto-vibrate).
  Future<List<ManagedMosque>> refreshManaged() async {
    final user = _currentUser();
    if (user == null) {
      _managed = [];
      notifyListeners();
      return _managed;
    }
    _managed = await _api.myManagedMosques();
    var changed = false;
    for (final m in _managed) {
      final before = _localByCloudId[m.id];
      await _repository.upsertCloud(
        supabaseId: m.id,
        name: m.name,
        latitude: m.latitude,
        longitude: m.longitude,
        radiusMeters: m.radiusMeters,
        shareCode: m.shareCode,
      );
      if (before == null) changed = true;
    }
    if (changed) await onLocalMosquesChanged?.call();
    notifyListeners();
    return _managed;
  }

  void clearManaged() {
    _managed = [];
    notifyListeners();
  }

  /// Imam deleted a mosque: remove the cloud row and the local copy.
  Future<void> deleteManagedMosque(String cloudMosqueId) async {
    await _api.deleteMosque(cloudMosqueId);
    _managed.removeWhere((m) => m.id == cloudMosqueId);
    final local = await _repository.getBySupabaseId(cloudMosqueId);
    if (local != null) await _removeLocal(local);
    await onLocalMosquesChanged?.call();
    notifyListeners();
  }

  // ── Pull sync ────────────────────────────────────────────────────────

  /// Pulls the latest mosque info, times and announcements from Supabase.
  Future<void> refresh() async {
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      final ids = _ids.toList();
      if (ids.isEmpty) {
        _times = {};
        _announcements = [];
        _lastError = null;
        await _saveCache();
        return;
      }

      // 1. Mosque rows — mirror edits, drop mosques that were deleted.
      final cloud = await _api.fetchMosquesByIds(ids);
      final byId = {for (final m in cloud) m.id: m};
      var localChanged = false;
      for (final id in ids) {
        final local = _localByCloudId[id];
        if (local == null) continue;
        final remote = byId[id];
        if (remote == null || !remote.isActive) {
          await _removeLocal(local);
          localChanged = true;
          await _safeNotify(
            'Masjid removed',
            '"${local.name}" ab app par available nahi (Imam ne hata di).',
          );
          continue;
        }
        final updated = local.name != remote.name ||
            local.radiusMeters != remote.radiusMeters ||
            local.latitude != remote.latitude ||
            local.longitude != remote.longitude;
        if (updated) {
          await _repository.upsertCloud(
            supabaseId: remote.id,
            name: remote.name,
            latitude: remote.latitude,
            longitude: remote.longitude,
            radiusMeters: remote.radiusMeters,
            shareCode: remote.shareCode,
          );
          localChanged = true;
        }
      }
      final liveIds = ids.where((id) => byId[id]?.isActive ?? false).toList();

      // 2. Jamaat times + announcements.
      final times = await _api.fetchPrayerTimesFor(liveIds);
      final anns = await _api.fetchAnnouncements(liveIds);
      _times = {for (final t in times) t.mosqueId: t};
      _announcements = anns;
      _lastSync = DateTime.now();
      _lastError = null;
      await _saveCache();
      if (localChanged) await onLocalMosquesChanged?.call();
    } catch (e) {
      _lastError = friendlyCloudError(e);
      debugPrint('MosqueSyncService.refresh failed: $e');
    } finally {
      _refreshing = false;
      notifyListeners();
      if (_refreshQueued) {
        _refreshQueued = false;
        unawaited(refresh());
      }
    }
  }

  // ── Realtime ─────────────────────────────────────────────────────────

  void _resubscribe() {
    _removeChannel();
    if (_ids.isEmpty) return;
    final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      return;
    }
    final ids = _ids.take(100).toList();
    final inIds = PostgresChangeFilter(
      type: PostgresChangeFilterType.inFilter,
      column: 'mosque_id',
      value: ids,
    );

    _channel = client
        .channel('masjid-sync-${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConfig.prayerTimesTable,
          filter: inIds,
          callback: _onTimesChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConfig.announcementsTable,
          filter: inIds,
          callback: _onAnnouncementUpsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConfig.announcementsTable,
          filter: inIds,
          callback: _onAnnouncementUpsert,
        )
        // Delete events can't be filtered server-side; ignore foreign ones.
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: SupabaseConfig.announcementsTable,
          callback: _onAnnouncementDelete,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConfig.mosquesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.inFilter,
            column: 'id',
            value: ids,
          ),
          callback: (_) => unawaited(refresh()),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: SupabaseConfig.mosquesTable,
          callback: (p) {
            final id = p.oldRecord['id'];
            if (id is String && _ids.contains(id)) unawaited(refresh());
          },
        )
        .subscribe((status, error) {
      final live = status == RealtimeSubscribeStatus.subscribed;
      if (live && !_live) {
        // (Re)connected — pull anything missed while offline.
        unawaited(refresh());
      }
      _live = live;
      notifyListeners();
    });
  }

  void _removeChannel() {
    final ch = _channel;
    _channel = null;
    _live = false;
    if (ch != null) {
      try {
        unawaited(Supabase.instance.client.removeChannel(ch));
      } catch (_) {}
    }
  }

  void _onTimesChange(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = payload.oldRecord['mosque_id'];
      if (id is String) _times.remove(id);
    } else {
      if (payload.newRecord.isEmpty) return;
      final t = CloudPrayerTimes.fromJson(payload.newRecord);
      final old = _times[t.mosqueId];
      _times[t.mosqueId] = t;
      if (old != null && _timesDiffer(old, t)) {
        unawaited(_safeNotify(
          '🕌 ${mosqueName(t.mosqueId)} — Jamaat time update',
          'Fajr ${t.fajr} • Zuhr ${t.dhuhr} • Asr ${t.asr} • '
              'Maghrib ${t.maghrib} • Isha ${t.isha}'
              '${t.jumuah != null && t.jumuah!.isNotEmpty ? ' • Jumuah ${t.jumuah}' : ''}',
        ));
      }
    }
    unawaited(_saveCache());
    notifyListeners();
  }

  void _onAnnouncementUpsert(PostgresChangePayload payload) {
    if (payload.newRecord.isEmpty) return;
    final a = CloudAnnouncement.fromJson(payload.newRecord);
    final index = _announcements.indexWhere((x) => x.id == a.id);
    if (index >= 0) {
      _announcements[index] = a;
    } else {
      _announcements.insert(0, a);
      _announcements.sort((x, y) => y.createdAt.compareTo(x.createdAt));
      if (payload.eventType == PostgresChangeEvent.insert) {
        unawaited(_safeNotify('📢 ${mosqueName(a.mosqueId)}: ${a.title}', a.content));
      }
    }
    unawaited(_saveCache());
    notifyListeners();
  }

  void _onAnnouncementDelete(PostgresChangePayload payload) {
    final id = payload.oldRecord['id'];
    if (id is! String) return;
    final before = _announcements.length;
    _announcements.removeWhere((a) => a.id == id);
    if (_announcements.length != before) {
      unawaited(_saveCache());
      notifyListeners();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  bool _timesDiffer(CloudPrayerTimes a, CloudPrayerTimes b) =>
      a.fajr != b.fajr ||
      a.dhuhr != b.dhuhr ||
      a.asr != b.asr ||
      a.maghrib != b.maghrib ||
      a.isha != b.isha ||
      a.jumuah != b.jumuah;

  User? _currentUser() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> _safeNotify(String title, String body) async {
    try {
      await _notifications.show(title: title, body: body);
    } catch (_) {}
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timesRaw = prefs.getString(_prefsTimes);
      if (timesRaw != null) {
        final list = jsonDecode(timesRaw) as List;
        _times = {
          for (final e in list)
            (e as Map)['mosque_id'] as String:
                CloudPrayerTimes.fromJson(Map<String, dynamic>.from(e)),
        };
      }
      final annRaw = prefs.getString(_prefsAnnouncements);
      if (annRaw != null) {
        _announcements = (jsonDecode(annRaw) as List)
            .map((e) => CloudAnnouncement.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      final last = prefs.getString(_prefsLastSync);
      _lastSync = last == null ? null : DateTime.tryParse(last);
    } catch (e) {
      debugPrint('sync cache load failed: $e');
    }
    notifyListeners();
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsTimes,
        jsonEncode(_times.values.map((t) => t.toJson()).toList()),
      );
      await prefs.setString(
        _prefsAnnouncements,
        jsonEncode(_announcements.take(200).map((a) => a.toJson()).toList()),
      );
      if (_lastSync != null) {
        await prefs.setString(_prefsLastSync, _lastSync!.toIso8601String());
      }
    } catch (_) {}
  }
}
