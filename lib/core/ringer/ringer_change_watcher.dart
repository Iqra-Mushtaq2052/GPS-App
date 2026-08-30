import 'package:flutter/services.dart';

/// Streams an event every time Android reports the ringer/DND state changed
/// — from anyone: the user, this app, or the OS. See
/// `RingerModeWatcher.kt` for the native side (two system broadcasts).
///
/// This is what lets the proximity engine react to a manual un-silence
/// within about a second, instead of waiting for the next GPS fix.
class RingerChangeWatcher {
  static const _channel = EventChannel('com.gpsapp.gps_app/ringer_watcher');

  Stream<void>? _stream;

  Stream<void> get changes =>
      _stream ??= _channel.receiveBroadcastStream().map((_) {});
}
