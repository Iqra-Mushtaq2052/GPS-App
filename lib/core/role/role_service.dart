import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// `imam` = Masjid management (Imam or committee member, needs login).
/// `user` = Namazi (no login, can only download mosques from the store).
enum AppRole { imam, user }

/// Manages the selected role (Imam / User) persisted in SharedPreferences.
///
/// NOTE: the role only decides which UI is shown. Real permissions are
/// enforced by Supabase (auth + RLS), so picking "Imam" without an approved
/// account does not allow adding or editing any mosque.
class RoleService {
  static const _prefsRoleKey = 'app_role';
  static const _prefsDeviceIdKey = 'app_device_id';

  Future<AppRole?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsRoleKey);
    if (stored == null) return null;
    return AppRole.values.firstWhere(
      (r) => r.name == stored,
      orElse: () => AppRole.user,
    );
  }

  Future<void> setRole(AppRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsRoleKey, role.name);
  }

  Future<bool> hasRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_prefsRoleKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsRoleKey);
  }

  /// Stable anonymous id for this install (used for follower counts).
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsDeviceIdKey);
    if (id == null || id.length < 8) {
      id = 'device_${const Uuid().v4()}';
      await prefs.setString(_prefsDeviceIdKey, id);
    }
    return id;
  }

  Future<bool> isImam() async {
    final role = await getRole();
    return role == AppRole.imam;
  }
}
