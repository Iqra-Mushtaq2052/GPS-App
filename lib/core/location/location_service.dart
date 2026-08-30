import 'package:geolocator/geolocator.dart';

/// Thin wrapper around [Geolocator] for one-shot, high-accuracy position
/// fetches (used when the user is standing at a masjid and taps "save").
class LocationService {
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  /// Returns a high-accuracy position, or throws if location services are
  /// disabled or permission has not been granted.
  ///
  /// Forces the legacy LocationManager so a masjid can be saved with no
  /// data connection: the fused provider leans on network positioning and
  /// can return nothing at all when offline. [timeLimit] keeps the UI from
  /// hanging forever while the GPS chip performs a cold start.
  Future<Position> getCurrentPosition({
    Duration timeLimit = const Duration(minutes: 3),
  }) {
    return Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        forceLocationManager: true,
        timeLimit: timeLimit,
      ),
    );
  }

  double distanceMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
