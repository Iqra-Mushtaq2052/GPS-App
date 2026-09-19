import 'package:shared_preferences/shared_preferences.dart';

enum PrayerStatus {
  jamaat, // Offered with Jama'at in Mosque
  individual, // Offered alone
  qaza, // Offered late
  none, // Not offered
}

class PrayerTrackerService {
  static const List<String> prayersList = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  static String _keyForDate(DateTime date, String prayer) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return 'pt_${y}_${m}_${d}_$prayer';
  }

  /// Returns the prayer status for a specific date and prayer
  static Future<PrayerStatus> getStatus(String prayer, [DateTime? date]) async {
    final target = date ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_keyForDate(target, prayer));

    if (val == 'jamaat') return PrayerStatus.jamaat;
    if (val == 'individual') return PrayerStatus.individual;
    if (val == 'qaza') return PrayerStatus.qaza;

    // Backward compatibility with old boolean storage
    final oldList = prefs.getStringList('prayer_tracker_${target.year.toString().padLeft(4, "0")}_${target.month.toString().padLeft(2, "0")}_${target.day.toString().padLeft(2, "0")}');
    if (oldList != null && oldList.contains(prayer)) {
      return PrayerStatus.individual;
    }

    return PrayerStatus.none;
  }

  /// Sets the prayer status for a specific date and prayer
  static Future<void> setStatus(String prayer, PrayerStatus status, [DateTime? date]) async {
    final target = date ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final key = _keyForDate(target, prayer);

    if (status == PrayerStatus.none) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, status.name);
    }
  }

  /// Returns all statuses for a given day as a Map
  static Future<Map<String, PrayerStatus>> getDailyStatuses([DateTime? date]) async {
    final target = date ?? DateTime.now();
    final Map<String, PrayerStatus> result = {};
    for (final p in prayersList) {
      result[p] = await getStatus(p, target);
    }
    return result;
  }

  /// Calculates completed prayer count for a day
  static Future<int> getCompletedCount([DateTime? date]) async {
    final map = await getDailyStatuses(date);
    return map.values.where((s) => s != PrayerStatus.none).length;
  }

  /// Calculates 7-day weekly regularity statistics (out of 35 total prayers)
  static Future<Map<String, dynamic>> getWeeklyStats() async {
    final now = DateTime.now();
    int totalOffered = 0;
    int jamaatCount = 0;
    int individualCount = 0;
    int qazaCount = 0;

    for (int i = 0; i < 7; i++) {
      final d = now.subtract(Duration(days: i));
      final map = await getDailyStatuses(d);

      for (final s in map.values) {
        if (s == PrayerStatus.jamaat) {
          jamaatCount++;
          totalOffered++;
        } else if (s == PrayerStatus.individual) {
          individualCount++;
          totalOffered++;
        } else if (s == PrayerStatus.qaza) {
          qazaCount++;
          totalOffered++;
        }
      }
    }

    final percentage = (totalOffered / 35.0 * 100).round();

    return {
      'totalOffered': totalOffered,
      'jamaatCount': jamaatCount,
      'individualCount': individualCount,
      'qazaCount': qazaCount,
      'percentage': percentage,
    };
  }

  /// Legacy helper for quick boolean toggle from home screen cards
  static Future<Set<String>> getCompletedPrayers([DateTime? date]) async {
    final map = await getDailyStatuses(date);
    return map.entries.where((e) => e.value != PrayerStatus.none).map((e) => e.key).toSet();
  }

  /// Legacy helper for toggling prayer from home screen cards
  static Future<Set<String>> togglePrayer(String prayerName, [DateTime? date]) async {
    final currentStatus = await getStatus(prayerName, date);
    final targetStatus = currentStatus == PrayerStatus.none ? PrayerStatus.individual : PrayerStatus.none;
    await setStatus(prayerName, targetStatus, date);
    return getCompletedPrayers(date);
  }
}
