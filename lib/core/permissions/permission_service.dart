import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Sequential permission requests, one at a time, as recommended by Android
/// (bundling requests together increases rejection rates). Background
/// location in particular must be requested *after* foreground location is
/// already granted, in its own step, per Android 10+ requirements.
class PermissionService {
  Future<bool> requestForegroundLocation() async {
    if (kIsWeb) return true;
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<bool> requestBackgroundLocation() async {
    if (kIsWeb) return true;
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  Future<bool> requestNotifications() async {
    if (kIsWeb) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb) return true;
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  Future<bool> hasForegroundLocation() async {
    if (kIsWeb) return true;
    return Permission.location.isGranted;
  }

  Future<bool> hasBackgroundLocation() async {
    if (kIsWeb) return true;
    return Permission.locationAlways.isGranted;
  }
}
