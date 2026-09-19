import 'package:geolocator/geolocator.dart';

/// Thin wrapper around [Geolocator] for position fetches.
class LocationService {
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  Future<Position?> getLastKnownPosition() =>
      Geolocator.getLastKnownPosition();

  /// Returns a quick position (last known or medium accuracy within 5 seconds),
  /// avoiding long GPS cold-start delays.
  Future<Position?> getQuickPosition() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  /// Returns a high-accuracy position for mosque saving.
  Future<Position> getCurrentPosition({
    Duration timeLimit = const Duration(seconds: 15),
  }) {
    return Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
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
