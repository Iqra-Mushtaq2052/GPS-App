import 'dart:math';

/// Calculates Qibla direction (bearing in degrees relative to True North)
/// from any location on Earth to the Holy Kaaba in Mecca (21.422487 N, 39.826206 E).
class QiblaService {
  static const double kaabaLat = 21.422487;
  static const double kaabaLng = 39.826206;

  /// Calculates initial bearing in degrees (0..360) towards Mecca
  static double calculateQiblaBearing(double latitude, double longitude) {
    final double phi1 = _degreesToRadians(latitude);
    final double lambda1 = _degreesToRadians(longitude);
    final double phi2 = _degreesToRadians(kaabaLat);
    final double lambda2 = _degreesToRadians(kaabaLng);

    final double deltaLambda = lambda2 - lambda1;

    final double y = sin(deltaLambda) * cos(phi2);
    final double x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);

    double bearing = atan2(y, x);
    bearing = _radiansToDegrees(bearing);
    return (bearing + 360) % 360;
  }

  static double _degreesToRadians(double degrees) => degrees * pi / 180.0;
  static double _radiansToDegrees(double radians) => radians * 180.0 / pi;
}
