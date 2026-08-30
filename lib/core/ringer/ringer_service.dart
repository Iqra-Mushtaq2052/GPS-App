import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_mode_advanced/sound_mode_advanced.dart';

/// What actually happened when a ringer change was attempted. Callers use
/// this to decide whether a notification is warranted — an earlier version
/// returned nothing and so announced "ringer restored" even when it had
/// changed nothing at all.
enum RingerActionResult {
  /// The ringer mode was really changed.
  changed,

  /// The phone was already in the desired mode; nothing was touched.
  alreadyInDesiredState,

  /// Do Not Disturb access is missing, so nothing could be done.
  noPermission,

  /// The app never silenced this phone (or the user changed the mode
  /// themselves afterwards), so restoring is not ours to do.
  notOurs,
}

/// Controls the Android ringer mode around a masjid visit.
///
/// Every operation reads the *real* current ringer mode first rather than
/// trusting an internal flag, so the app never claims to have changed
/// something it did not, and never overwrites a mode the user set by hand.
class RingerService {
  static const _prefsPreviousModeKey = 'ringer_service_previous_mode';
  static const _prefsSilencedByAppKey = 'ringer_service_silenced_by_app';

  Future<bool> hasDoNotDisturbAccess() async {
    final granted = await PermissionHandler.permissionsGranted;
    return granted ?? false;
  }

  Future<void> openDoNotDisturbSettings() =>
      PermissionHandler.openDoNotDisturbSetting();

  Future<RingerModeStatus> currentMode() => SoundMode.ringerModeStatus;

  /// True when the app currently believes it is the reason the phone is
  /// silent. Used by the UI to show honest status.
  Future<bool> silencedByApp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsSilencedByAppKey) ?? false;
  }

  /// Silences the phone, remembering the mode it was in first.
  ///
  /// If the phone is *already* silent this deliberately does nothing and
  /// records nothing: silencing an already-silent phone would otherwise
  /// store "silent" as the mode to restore later, leaving the phone stuck
  /// on silent forever.
  Future<RingerActionResult> silenceForPrayer() async {
    if (!await hasDoNotDisturbAccess()) return RingerActionResult.noPermission;

    final current = await SoundMode.ringerModeStatus;
    if (current == RingerModeStatus.silent) {
      return RingerActionResult.alreadyInDesiredState;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPreviousModeKey, current.name);
    await prefs.setBool(_prefsSilencedByAppKey, true);

    await SoundMode.setSoundMode(RingerModeStatus.silent);
    return RingerActionResult.changed;
  }

  /// Restores the mode that was active before [silenceForPrayer].
  ///
  /// Refuses to act unless this app is the one that silenced the phone AND
  /// the phone is still silent — if the user un-silenced it themselves in
  /// the meantime, their choice wins.
  Future<RingerActionResult> restorePreviousMode() async {
    final prefs = await SharedPreferences.getInstance();
    final silencedByApp = prefs.getBool(_prefsSilencedByAppKey) ?? false;
    if (!silencedByApp) return RingerActionResult.notOurs;

    if (!await hasDoNotDisturbAccess()) return RingerActionResult.noPermission;

    final current = await SoundMode.ringerModeStatus;
    if (current != RingerModeStatus.silent) {
      // The user took control; drop our claim without touching anything.
      await prefs.setBool(_prefsSilencedByAppKey, false);
      return RingerActionResult.notOurs;
    }

    final storedName = prefs.getString(_prefsPreviousModeKey);
    final previous = RingerModeStatus.values.firstWhere(
      (mode) => mode.name == storedName,
      orElse: () => RingerModeStatus.normal,
    );

    await SoundMode.setSoundMode(previous);
    await prefs.setBool(_prefsSilencedByAppKey, false);
    return RingerActionResult.changed;
  }
}
