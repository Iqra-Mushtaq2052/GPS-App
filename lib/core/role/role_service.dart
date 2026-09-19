import 'package:shared_preferences/shared_preferences.dart';

enum AppRole { imam, user }

/// Manages the selected role (Imam / User) persisted in SharedPreferences.
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

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsDeviceIdKey);
    if (id == null) {
      // Generate a unique device ID using timestamp + random
      id = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_prefsDeviceIdKey, id);
    }
    return id;
  }

  Future<bool> isImam() async {
    final role = await getRole();
    return role == AppRole.imam;
  }
}
