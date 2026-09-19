import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_mode_advanced/sound_mode_advanced.dart';

enum RingerActionResult {
  changed,
  alreadyInDesiredState,
  noPermission,
  notOurs,
}

/// Clean Auto-Vibrate RingerService — Built From Scratch.
///
/// Uses [SoundMode] plugin to switch phone to VIBRATE mode when inside
/// a mosque boundary, and restores to NORMAL when outside.
/// Persists silence state across app restarts so reopening the app inside
/// a mosque maintains the vibrate state correctly.
class RingerService {
  static const _prefsSilencedByAppKey = 'ringer_service_silenced_by_app';
  bool _silencedByUs = false;
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _silencedByUs = prefs.getBool(_prefsSilencedByAppKey) ?? false;
      _initialized = true;
    } catch (_) {}
  }

  /// Check if the app has DND (Do Not Disturb) access permission.
  Future<bool> hasDoNotDisturbAccess() async {
    try {
      return await PermissionHandler.permissionsGranted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open system DND settings so user can grant permission.
  Future<void> openDoNotDisturbSettings() async {
    try {
      await PermissionHandler.openDoNotDisturbSetting();
    } catch (_) {}
  }

  /// Returns true if this app is the one that changed the ringer mode.
  Future<bool> silencedByApp() async {
    await _init();
    return _silencedByUs;
  }

  /// Returns the current ringer mode status.
  Future<RingerModeStatus?> currentMode() async {
    try {
      final mode = await SoundMode.ringerModeStatus;
      return mode;
    } catch (_) {
      return null;
    }
  }

  /// Set phone to VIBRATE mode (Pure Vibrate — No DND, No Silent).
  Future<RingerActionResult> silenceForPrayer() async {
    await _init();
    try {
      // Check current mode first
      final mode = await SoundMode.ringerModeStatus;

      // Already in vibrate — no change needed
      if (mode == RingerModeStatus.vibrate) {
        _silencedByUs = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsSilencedByAppKey, true);
        return RingerActionResult.alreadyInDesiredState;
      }

      // Set to vibrate
      await SoundMode.setSoundMode(RingerModeStatus.vibrate);
      _silencedByUs = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsSilencedByAppKey, true);
      return RingerActionResult.changed;
    } catch (_) {
      return RingerActionResult.noPermission;
    }
  }

  /// Restore phone to NORMAL ringer mode.
  Future<RingerActionResult> restorePreviousMode() async {
    await _init();
    if (!_silencedByUs) return RingerActionResult.notOurs;

    try {
      final mode = await SoundMode.ringerModeStatus;

      // Already normal — nothing to restore
      if (mode == RingerModeStatus.normal) {
        _silencedByUs = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsSilencedByAppKey, false);
        return RingerActionResult.alreadyInDesiredState;
      }

      // Restore to normal
      await SoundMode.setSoundMode(RingerModeStatus.normal);
      _silencedByUs = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsSilencedByAppKey, false);
      return RingerActionResult.changed;
    } catch (_) {
      return RingerActionResult.noPermission;
    }
  }
}
