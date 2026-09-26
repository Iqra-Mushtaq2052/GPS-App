import 'package:supabase_flutter/supabase_flutter.dart';

import '../role/role_service.dart';
import 'supabase_config.dart';

// ─────────────────────────────────────────────────────────────────────────
//  Models
// ─────────────────────────────────────────────────────────────────────────

double _toDouble(Object? v) => (v as num).toDouble();
int _toInt(Object? v, [int fallback = 0]) => v == null ? fallback : (v as num).toInt();

/// A mosque as stored in Supabase.
class CloudMosque {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String shareCode;
  final String? address;
  final bool isActive;

  const CloudMosque({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.shareCode,
    this.address,
    this.isActive = true,
  });

  factory CloudMosque.fromJson(Map<String, dynamic> json) {
    return CloudMosque(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      radiusMeters: _toInt(json['radius_meters'], 40),
      shareCode: (json['share_code'] as String?) ?? '',
      address: json['address'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}

/// A registered mosque returned by the Masjid Store (nearby search).
class StoreMosque extends CloudMosque {
  final double distanceMeters;
  final int followerCount;
  final bool hasTimes;

  const StoreMosque({
    required super.id,
    required super.name,
    required super.latitude,
    required super.longitude,
    required super.radiusMeters,
    required super.shareCode,
    super.address,
    required this.distanceMeters,
    required this.followerCount,
    required this.hasTimes,
  });

  factory StoreMosque.fromJson(Map<String, dynamic> json) {
    return StoreMosque(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      radiusMeters: _toInt(json['radius_meters'], 40),
      shareCode: (json['share_code'] as String?) ?? '',
      address: json['address'] as String?,
      distanceMeters: _toDouble(json['distance_m']),
      followerCount: _toInt(json['follower_count']),
      hasTimes: (json['has_times'] as bool?) ?? false,
    );
  }
}

/// A mosque the signed-in imam / committee member manages.
class ManagedMosque extends CloudMosque {
  /// 'imam' or 'committee'.
  final String myRole;
  final int followerCount;

  bool get isImam => myRole == 'imam';

  const ManagedMosque({
    required super.id,
    required super.name,
    required super.latitude,
    required super.longitude,
    required super.radiusMeters,
    required super.shareCode,
    super.address,
    super.isActive,
    required this.myRole,
    required this.followerCount,
  });

  factory ManagedMosque.fromJson(Map<String, dynamic> json) {
    return ManagedMosque(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      radiusMeters: _toInt(json['radius_meters'], 40),
      shareCode: (json['share_code'] as String?) ?? '',
      address: json['address'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      myRole: (json['my_role'] as String?) ?? 'committee',
      followerCount: _toInt(json['follower_count']),
    );
  }
}

/// Jamaat times set by the imam / committee.
class CloudPrayerTimes {
  final String mosqueId;
  final String fajr;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String? jumuah;
  final DateTime updatedAt;

  const CloudPrayerTimes({
    required this.mosqueId,
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.jumuah,
    required this.updatedAt,
  });

  factory CloudPrayerTimes.fromJson(Map<String, dynamic> json) {
    return CloudPrayerTimes(
      mosqueId: json['mosque_id'] as String,
      fajr: (json['fajr'] as String?) ?? '05:00',
      dhuhr: (json['dhuhr'] as String?) ?? '13:00',
      asr: (json['asr'] as String?) ?? '17:00',
      maghrib: (json['maghrib'] as String?) ?? '18:30',
      isha: (json['isha'] as String?) ?? '20:00',
      jumuah: json['jumuah'] as String?,
      updatedAt: DateTime.tryParse((json['updated_at'] as String?) ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mosque_id': mosqueId,
        'fajr': fajr,
        'dhuhr': dhuhr,
        'asr': asr,
        'maghrib': maghrib,
        'isha': isha,
        'jumuah': jumuah,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  /// Converts HH:mm strings into today's DateTimes (Fajr … Isha, in order).
  Map<String, DateTime> toTodayDateTimes() {
    final now = DateTime.now();
    DateTime parse(String hhmm) {
      final parts = hhmm.split(':');
      final h = int.tryParse(parts.first) ?? 0;
      final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return DateTime(now.year, now.month, now.day, h, m);
    }

    return {
      'Fajr': parse(fajr),
      'Dhuhr': parse(dhuhr),
      'Asr': parse(asr),
      'Maghrib': parse(maghrib),
      'Isha': parse(isha),
    };
  }
}

/// A mosque announcement / notice.
class CloudAnnouncement {
  final String id;
  final String mosqueId;
  final String title;
  final String content;
  final DateTime createdAt;

  const CloudAnnouncement({
    required this.id,
    required this.mosqueId,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  factory CloudAnnouncement.fromJson(Map<String, dynamic> json) {
    return CloudAnnouncement(
      id: json['id'] as String,
      mosqueId: json['mosque_id'] as String,
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mosque_id': mosqueId,
        'title': title,
        'content': content,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

/// A committee member of a mosque.
class CommitteeMember {
  final String userId;
  final String email;
  final String fullName;
  final String title;

  const CommitteeMember({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.title,
  });

  factory CommitteeMember.fromJson(Map<String, dynamic> json) => CommitteeMember(
        userId: json['user_id'] as String,
        email: (json['email'] as String?) ?? '',
        fullName: (json['full_name'] as String?) ?? '',
        title: (json['title'] as String?) ?? 'Committee Member',
      );
}

/// Turns server error codes (raised by the SQL functions) into friendly text.
String friendlyCloudError(Object error) {
  final raw = error is PostgrestException
      ? error.message
      : error is AuthException
          ? error.message
          : error.toString();
  final details = error is PostgrestException ? error.details?.toString() : null;

  if (raw.contains('DUPLICATE_MOSQUE')) {
    return 'Is jagah (50 meter ke andar) pehle se masjid registered hai'
        '${details != null && details.isNotEmpty ? ': "$details"' : ''}.';
  }
  if (raw.contains('IMAM_NOT_APPROVED')) {
    return 'Aap ka Imam account abhi admin se approve nahi hua.';
  }
  if (raw.contains('NOT_AUTHENTICATED')) return 'Pehle Imam account se login karein.';
  if (raw.contains('USER_NOT_FOUND')) {
    return 'Is email ka koi account nahi mila. Committee member pehle app mein '
        '"Imam / Committee" account banaye.';
  }
  if (raw.contains('ALREADY_IMAM')) return 'Aap khud is masjid ke Imam hain.';
  if (raw.contains('ONLY_IMAM')) return 'Ye kaam sirf masjid ka Imam kar sakta hai.';
  if (raw.contains('NAME_REQUIRED')) return 'Naam likhna zaroori hai.';
  if (raw.contains('row-level security') || raw.contains('permission denied')) {
    return 'Aap ko is masjid mein ye tabdeeli karne ki ijazat nahi.';
  }
  if (raw.contains('SocketException') || raw.contains('Failed host lookup') ||
      raw.contains('ClientException')) {
    return 'Internet connection nahi hai. Dobara koshish karein.';
  }
  if (raw.contains('Invalid login credentials')) return 'Email ya password ghalat hai.';
  if (raw.contains('Email not confirmed')) {
    return 'Email confirm nahi hui. Apni email mein aaya link khol kar confirm karein.';
  }
  if (raw.contains('User already registered')) {
    return 'Is email se account pehle se bana hua hai. Login karein.';
  }
  return raw;
}

// ─────────────────────────────────────────────────────────────────────────
//  Service
// ─────────────────────────────────────────────────────────────────────────

/// All Supabase reads / writes for mosques, jamaat times, announcements,
/// committee and followers. Write access is enforced server-side by RLS.
class SupabaseService {
  final RoleService _roleService;

  SupabaseService(this._roleService);

  SupabaseClient get client => Supabase.instance.client;

  static const _mosqueColumns =
      'id, name, latitude, longitude, radius_meters, share_code, address, is_active';

  // ── Masjid Store ─────────────────────────────────────────────────────

  /// Registered (approved) mosques within [radiusKm] of the point.
  Future<List<StoreMosque>> nearbyMosques({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
  }) async {
    final res = await client.rpc('nearby_mosques', params: {
      'p_lat': latitude,
      'p_lng': longitude,
      'p_radius_km': radiusKm,
    });
    return (res as List)
        .map((e) => StoreMosque.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Fetch a mosque by its 6-char share code.
  Future<CloudMosque?> fetchMosqueByCode(String code) async {
    final response = await client
        .from(SupabaseConfig.mosquesTable)
        .select(_mosqueColumns)
        .eq('share_code', code.toUpperCase().trim())
        .maybeSingle();
    if (response == null) return null;
    return CloudMosque.fromJson(response);
  }

  /// Current server copies of the given mosques (missing = deleted/hidden).
  Future<List<CloudMosque>> fetchMosquesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final res = await client
        .from(SupabaseConfig.mosquesTable)
        .select(_mosqueColumns)
        .inFilter('id', ids);
    return (res as List)
        .map((e) => CloudMosque.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> followMosque(String mosqueId) async {
    final deviceId = await _roleService.getDeviceId();
    await client.rpc('follow_mosque', params: {
      'p_mosque_id': mosqueId,
      'p_device_id': deviceId,
    });
  }

  Future<void> unfollowMosque(String mosqueId) async {
    final deviceId = await _roleService.getDeviceId();
    await client.rpc('unfollow_mosque', params: {
      'p_mosque_id': mosqueId,
      'p_device_id': deviceId,
    });
  }

  // ── Imam / committee management ──────────────────────────────────────

  /// Registers a mosque (approved imams only; duplicates within 50 m fail).
  Future<CloudMosque> registerMosque({
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
    String? address,
  }) async {
    final res = await client.rpc('register_mosque', params: {
      'p_name': name,
      'p_lat': latitude,
      'p_lng': longitude,
      'p_radius': radiusMeters,
      'p_address': address,
    });
    final map = res is List ? res.first : res;
    return CloudMosque.fromJson(Map<String, dynamic>.from(map as Map));
  }

  Future<List<ManagedMosque>> myManagedMosques() async {
    final res = await client.rpc('my_managed_mosques');
    return (res as List)
        .map((e) => ManagedMosque.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> updateMosque({
    required String cloudMosqueId,
    String? name,
    int? radiusMeters,
    double? latitude,
    double? longitude,
  }) async {
    final data = <String, dynamic>{
      'name': ?name,
      'radius_meters': ?radiusMeters,
      'latitude': ?latitude,
      'longitude': ?longitude,
    };
    if (data.isEmpty) return;
    await client.from(SupabaseConfig.mosquesTable).update(data).eq('id', cloudMosqueId);
  }

  /// Deletes a mosque (imam only). Times, announcements, committee and
  /// followers are removed by ON DELETE CASCADE.
  Future<void> deleteMosque(String cloudMosqueId) async {
    final res = await client
        .from(SupabaseConfig.mosquesTable)
        .delete()
        .eq('id', cloudMosqueId)
        .select('id');
    if ((res as List).isEmpty) {
      throw const PostgrestException(message: 'ONLY_IMAM');
    }
  }

  Future<List<CommitteeMember>> listCommittee(String cloudMosqueId) async {
    final res = await client.rpc('list_committee', params: {'p_mosque_id': cloudMosqueId});
    return (res as List)
        .map((e) => CommitteeMember.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addCommitteeMember({
    required String cloudMosqueId,
    required String email,
    String title = 'Committee Member',
  }) async {
    await client.rpc('add_committee_member', params: {
      'p_mosque_id': cloudMosqueId,
      'p_email': email,
      'p_title': title,
    });
  }

  Future<void> removeCommitteeMember({
    required String cloudMosqueId,
    required String userId,
  }) async {
    await client.rpc('remove_committee_member', params: {
      'p_mosque_id': cloudMosqueId,
      'p_user_id': userId,
    });
  }

  // ── Prayer times ─────────────────────────────────────────────────────

  Future<void> updatePrayerTimes({
    required String cloudMosqueId,
    required String fajr,
    required String dhuhr,
    required String asr,
    required String maghrib,
    required String isha,
    String? jumuah,
  }) async {
    await client.from(SupabaseConfig.prayerTimesTable).upsert({
      'mosque_id': cloudMosqueId,
      'fajr': fajr,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
      'jumuah': jumuah,
      'updated_by': client.auth.currentUser?.id,
    }, onConflict: 'mosque_id');
  }

  Future<CloudPrayerTimes?> fetchPrayerTimes(String cloudMosqueId) async {
    final response = await client
        .from(SupabaseConfig.prayerTimesTable)
        .select()
        .eq('mosque_id', cloudMosqueId)
        .maybeSingle();
    if (response == null) return null;
    return CloudPrayerTimes.fromJson(response);
  }

  Future<List<CloudPrayerTimes>> fetchPrayerTimesFor(List<String> ids) async {
    if (ids.isEmpty) return [];
    final res = await client
        .from(SupabaseConfig.prayerTimesTable)
        .select()
        .inFilter('mosque_id', ids);
    return (res as List)
        .map((e) => CloudPrayerTimes.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Announcements ────────────────────────────────────────────────────

  Future<void> createAnnouncement({
    required String cloudMosqueId,
    required String title,
    required String content,
  }) async {
    await client.from(SupabaseConfig.announcementsTable).insert({
      'mosque_id': cloudMosqueId,
      'title': title,
      'content': content,
      'created_by': client.auth.currentUser?.id,
    });
  }

  Future<List<CloudAnnouncement>> fetchAnnouncements(
    List<String> cloudMosqueIds, {
    int limit = 100,
  }) async {
    if (cloudMosqueIds.isEmpty) return [];
    final response = await client
        .from(SupabaseConfig.announcementsTable)
        .select()
        .inFilter('mosque_id', cloudMosqueIds)
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((json) => CloudAnnouncement.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await client.from(SupabaseConfig.announcementsTable).delete().eq('id', announcementId);
  }
}
