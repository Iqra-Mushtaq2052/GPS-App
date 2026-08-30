import 'package:adhan_dart/adhan_dart.dart';

/// Wraps `adhan_dart` to compute today's prayer times fully offline from a
/// pair of coordinates, and to answer "is it prayer time right now?" which
/// gates the auto-silent trigger (so entering a masjid outside prayer
/// windows does not silence the phone).
class PrayerTimeService {
  PrayerTimeService({Madhab madhab = Madhab.hanafi}) {
    _params = CalculationMethodParameters.muslimWorldLeague()..madhab = madhab;
  }

  late final CalculationParameters _params;

  PrayerTimes _prayerTimesFor(double latitude, double longitude, DateTime date) {
    return PrayerTimes(
      coordinates: Coordinates(latitude, longitude),
      date: date,
      calculationParameters: _params,
      precision: true,
    );
  }

  /// Today's five prayer times (local DateTime) for the given coordinates.
  Map<String, DateTime> todayTimes(double latitude, double longitude) {
    final times = _prayerTimesFor(latitude, longitude, DateTime.now());
    return {
      'Fajr': times.fajr.toLocal(),
      'Dhuhr': times.dhuhr.toLocal(),
      'Asr': times.asr.toLocal(),
      'Maghrib': times.maghrib.toLocal(),
      'Isha': times.isha.toLocal(),
    };
  }

  /// True if [at] (default: now) falls within [window] of any prayer time
  /// for the given coordinates. Used to decide whether a geofence entry
  /// should trigger silent mode.
  bool isPrayerTime({
    required double latitude,
    required double longitude,
    DateTime? at,
    Duration window = const Duration(minutes: 15),
  }) {
    final now = at ?? DateTime.now();
    final times = todayTimes(latitude, longitude);
    for (final prayerTime in times.values) {
      final diff = now.difference(prayerTime).abs();
      if (diff <= window) return true;
    }
    return false;
  }
}
