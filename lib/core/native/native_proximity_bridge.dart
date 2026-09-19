import 'dart:convert';
import 'package:flutter/services.dart';
import '../../data/db/app_database.dart';

class NativeProximityBridge {
  static const MethodChannel _channel = MethodChannel('com.gpsapp.gps_app/native_service');

  static String serializeMosques(List<Mosque> mosques) {
    final list = mosques.map((m) => {
      'id': m.id,
      'name': m.name,
      'lat': m.latitude,
      'lng': m.longitude,
      'radius': m.radiusMeters,
      'enabled': m.isEnabled,
    }).toList();
    return jsonEncode(list);
  }

  static Future<void> startNativeService(List<Mosque> mosques) async {
    try {
      final jsonStr = serializeMosques(mosques);
      await _channel.invokeMethod('startNativeService', {
        'mosquesJson': jsonStr,
      });
    } catch (e) {
      // Ignored if unsupported platform
    }
  }

  static Future<void> stopNativeService() async {
    try {
      await _channel.invokeMethod('stopNativeService');
    } catch (_) {}
  }

  static Future<void> syncMosques(List<Mosque> mosques) async {
    try {
      final jsonStr = serializeMosques(mosques);
      await _channel.invokeMethod('syncMosques', {
        'mosquesJson': jsonStr,
      });
    } catch (_) {}
  }
}
