import 'package:permission_handler/permission_handler.dart';

/// Sequential permission requests, one at a time, as recommended by Android
/// (bundling requests together increases rejection rates). Background
/// location in particular must be requested *after* foreground location is
/// already granted, in its own step, per Android 10+ requirements.
class PermissionService {
  Future<bool> requestForegroundLocation() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<bool> requestBackgroundLocation() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  Future<bool> requestNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> isIgnoringBatteryOptimizations() =>
      Permission.ignoreBatteryOptimizations.isGranted;

  Future<bool> requestIgnoreBatteryOptimizations() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  Future<bool> hasForegroundLocation() => Permission.location.isGranted;

  Future<bool> hasBackgroundLocation() => Permission.locationAlways.isGranted;
}
