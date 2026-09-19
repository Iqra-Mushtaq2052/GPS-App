import 'package:supabase_flutter/supabase_flutter.dart';

import '../role/role_service.dart';
import 'supabase_config.dart';

/// Cloud mosque data model returned from Supabase.
class CloudMosque {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String shareCode;
  final String imamDeviceId;

  const CloudMosque({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.shareCode,
    required this.imamDeviceId,
  });

  factory CloudMosque.fromJson(Map<String, dynamic> json) {
    return CloudMosque(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: json['radius_meters'] as int,
      shareCode: json['share_code'] as String,
      imamDeviceId: json['imam_device_id'] as String,
    );
  }
}

/// Cloud prayer times model.
class CloudPrayerTimes {
  final String mosqueId;
  final String fajr;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final DateTime updatedAt;

  const CloudPrayerTimes({
    required this.mosqueId,
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.updatedAt,
  });

  factory CloudPrayerTimes.fromJson(Map<String, dynamic> json) {
    return CloudPrayerTimes(
      mosqueId: json['mosque_id'] as String,
      fajr: json['fajr'] as String,
      dhuhr: json['dhuhr'] as String,
      asr: json['asr'] as String,
      maghrib: json['maghrib'] as String,
      isha: json['isha'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts imam-set HH:mm string times to today's DateTimes.
  Map<String, DateTime> toTodayDateTimes() {
    final now = DateTime.now();
    DateTime parseTime(String hhmm) {
      final parts = hhmm.split(':');
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    return {
      'Fajr': parseTime(fajr),
      'Dhuhr': parseTime(dhuhr),
      'Asr': parseTime(asr),
      'Maghrib': parseTime(maghrib),
      'Isha': parseTime(isha),
    };
  }
}

/// Cloud Announcement model.
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
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Handles all Supabase interactions: mosque upload, prayer time sync,
/// mosque lookup by share code, announcements.
class SupabaseService {
  final RoleService _roleService;

  SupabaseService(this._roleService);

  SupabaseClient get _client => Supabase.instance.client;

  // ── Mosque Operations ──────────────────────────────────────────────

  /// Upload a new mosque to Supabase. Returns the cloud mosque ID and share code.
  Future<({String id, String shareCode})> uploadMosque({
    required String name,
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    final deviceId = await _roleService.getDeviceId();
    final shareCode = _generateShareCode();

    final response = await _client
        .from(SupabaseConfig.mosquesTable)
        .insert({
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'radius_meters': radiusMeters,
          'share_code': shareCode,
          'imam_device_id': deviceId,
        })
        .select('id, share_code')
        .single();

    return (
      id: response['id'] as String,
      shareCode: response['share_code'] as String,
    );
  }

  /// Fetch a mosque by its 6-char share code (for users joining).
  Future<CloudMosque?> fetchMosqueByCode(String code) async {
    try {
      final response = await _client
          .from(SupabaseConfig.mosquesTable)
          .select()
          .eq('share_code', code.toUpperCase().trim())
          .maybeSingle();

      if (response == null) return null;
      return CloudMosque.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  // ── Prayer Time Operations ─────────────────────────────────────────

  /// Set or update prayer times for a mosque (imam only).
  Future<void> updatePrayerTimes({
    required String cloudMosqueId,
    required String fajr,
    required String dhuhr,
    required String asr,
    required String maghrib,
    required String isha,
  }) async {
    await _client.from(SupabaseConfig.prayerTimesTable).upsert({
      'mosque_id': cloudMosqueId,
      'fajr': fajr,
      'dhuhr': dhuhr,
      'asr': asr,
      'maghrib': maghrib,
      'isha': isha,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Fetch latest prayer times for a mosque from Supabase.
  Future<CloudPrayerTimes?> fetchPrayerTimes(String cloudMosqueId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.prayerTimesTable)
          .select()
          .eq('mosque_id', cloudMosqueId)
          .maybeSingle();

      if (response == null) return null;
      return CloudPrayerTimes.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Delete a mosque from Supabase (imam only).
  Future<void> deleteMosque(String cloudMosqueId) async {
    await _client
        .from(SupabaseConfig.mosquesTable)
        .delete()
        .eq('id', cloudMosqueId);
  }

  // ── Announcement Operations ──────────────────────────────────────

  /// Create a new announcement for a mosque
  Future<void> createAnnouncement({
    required String cloudMosqueId,
    required String title,
    required String content,
  }) async {
    await _client.from('announcements').insert({
      'mosque_id': cloudMosqueId,
      'title': title,
      'content': content,
    });
  }

  /// Fetch all announcements for a list of mosque IDs
  Future<List<CloudAnnouncement>> fetchAnnouncements(List<String> cloudMosqueIds) async {
    if (cloudMosqueIds.isEmpty) return [];
    try {
      final response = await _client
          .from('announcements')
          .select()
          .inFilter('mosque_id', cloudMosqueIds)
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      return list.map((json) => CloudAnnouncement.fromJson(json as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete an announcement
  Future<void> deleteAnnouncement(String announcementId) async {
    await _client.from('announcements').delete().eq('id', announcementId);
  }

  // ── Helpers ───────────────────────────────────────────────────────

  /// Generate a random 6-character alphanumeric share code.
  String _generateShareCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    var seed = random;
    for (int i = 0; i < 6; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buffer.write(chars[seed % chars.length]);
    }
    return buffer.toString();
  }
}
