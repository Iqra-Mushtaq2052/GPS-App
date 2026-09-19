import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../background/proximity_engine.dart';
import '../../core/ringer/ringer_service.dart';
import '../../core/role/role_service.dart';
import '../role/role_selection_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _backgroundLocationGranted;
  bool? _batteryOptimizationIgnored;
  bool _ignorePrayerTime = true;
  String? _testSilenceResult;
  AppRole? _currentRole;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadStarted) {
      _loadStarted = true;
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    final scope = AppScope.of(context);
    final bgLocation = await scope.permissions.hasBackgroundLocation();
    final batteryOk = await scope.permissions.isIgnoringBatteryOptimizations();
    final prefs = await SharedPreferences.getInstance();
    final ignorePrayerTime = prefs.getBool(prefsIgnorePrayerTimeKey) ?? true;
    final role = await scope.roleService.getRole();
    if (mounted) {
      setState(() {
        _backgroundLocationGranted = bgLocation;
        _batteryOptimizationIgnored = batteryOk;
        _ignorePrayerTime = ignorePrayerTime;
        _currentRole = role;
      });
    }
  }

  Future<void> _logout() async {
    final scope = AppScope.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to log out? You can log in again as Imam or User.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await scope.roleService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
        (route) => false,
      );
    }
  }

  Future<void> _testSilenceNow() async {
    final scope = AppScope.of(context);
    setState(() => _testSilenceResult = null);
    final result = await scope.ringer.silenceForPrayer();
    if (result == RingerActionResult.changed) {
      await scope.notifications.show(
        title: 'Test: phone silenced',
        body: 'This is a test notification. Ringer is now silent — '
            'restore using "Restore Ringer".',
      );
    }
    if (!mounted) return;
    setState(() {
      _testSilenceResult = switch (result) {
        RingerActionResult.changed =>
          'Success — phone is NOW silent and will stay silent. Check it '
              'yourself, then press "Restore Ringer".',
        RingerActionResult.alreadyInDesiredState =>
          'Phone was already silent — no changes made. Make the ringer '
              'normal first, then test.',
        RingerActionResult.noPermission =>
          'Failed — there was an issue changing the ringer mode.',
        RingerActionResult.notOurs => 'No changes made.',
      };
    });
  }

  Future<void> _restoreRinger() async {
    final scope = AppScope.of(context);
    final result = await scope.ringer.restorePreviousMode();
    if (!mounted) return;
    setState(() {
      _testSilenceResult = switch (result) {
        RingerActionResult.changed => 'Ringer restored to normal.',
        RingerActionResult.notOurs =>
          'App did not change the ringer (or you changed it yourself) — '
              'so nothing was done.',
        RingerActionResult.alreadyInDesiredState =>
          'Ringer was already in the correct state.',
        RingerActionResult.noPermission =>
          'Failed — there was an issue changing the ringer mode.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitleColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final dividerColor = theme.dividerColor;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF059669), isDark ? Colors.transparent : Colors.white.withValues(alpha: 0.0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text('Account Session', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _GlassCard(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _currentRole == AppRole.imam ? Icons.mosque : Icons.person,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: Text(
                'Logged in as: ${_currentRole == AppRole.imam ? "Imam" : "User (Namazi)"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _currentRole == AppRole.imam
                    ? 'Can create mosques and update prayer times'
                    : 'Can join mosques by code and view prayer times',
                style: TextStyle(color: subtitleColor, fontSize: 12),
              ),
              trailing: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Logout'),
                onPressed: _logout,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text('Permissions', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _GlassCard(
            child: Column(
              children: [
                _StatusTile(
                  title: 'Background Location',
                  granted: _backgroundLocationGranted,
                  onFix: () async {
                    await scope.permissions.requestBackgroundLocation();
                    _refreshStatuses();
                  },
                ),
                Divider(height: 1, color: dividerColor),
                _StatusTile(
                  title: 'Battery Optimization Ignored',
                  granted: _batteryOptimizationIgnored,
                  onFix: () async {
                    await scope.permissions.requestIgnoreBatteryOptimizations();
                    _refreshStatuses();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text('Security & Privacy', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.security, color: theme.colorScheme.primary),
                  title: const Text('GPS Location Privacy', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '100% On-Device Guarantee — Your GPS coordinates are processed locally in RAM and are NEVER sent or saved to any server.',
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '100% Private',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Divider(height: 1, color: dividerColor),
                ListTile(
                  leading: Icon(Icons.lock_outline, color: theme.colorScheme.secondary),
                  title: const Text('Imam Share Code Security', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'All Mosque share codes use 6-character encrypted keys with cloud row-level security (RLS).',
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text('Appearance', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette, color: theme.colorScheme.secondary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListenableBuilder(
                    listenable: themeNotifier,
                    builder: (context, _) {
                      return SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode),
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.phone_android),
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode),
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {themeNotifier.mode},
                        onSelectionChanged: (selected) {
                          themeNotifier.setMode(selected.first);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text('Testing', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.volume_off, color: theme.colorScheme.secondary),
                  title: const Text('Test Silence Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    _testSilenceResult ??
                        'Test silent-mode permission now without waiting for range. '
                            'Phone will stay silent until you restore it yourself.',
                    style: TextStyle(
                      color: _testSilenceResult != null ? theme.colorScheme.secondary : subtitleColor,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _restoreRinger,
                        child: const Text('Restore Ringer'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _testSilenceNow,
                        child: const Text('Silence Now'),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: dividerColor),
                SwitchListTile(
                  title: const Text('Testing Mode: Ignore prayer-time check'),
                  subtitle: Text(
                    'When ON, it will silence upon entering the geofence, whether '
                    'it is prayer time or not — for testing boundary/range only.',
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                  value: _ignorePrayerTime,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(prefsIgnorePrayerTimeKey, value);
                    setState(() => _ignorePrayerTime = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text('Information', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  title: const Text('Entry confirmation delay'),
                  subtitle: Text(
                    'GPS can jitter slightly on a small radius (20-60m), so it does '
                    'not trigger instantly upon entry — it confirms and silences only '
                    'after continuously staying inside for ~20 seconds.',
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                ),
                Divider(height: 1, color: dividerColor),
                ListTile(
                  leading: const Icon(Icons.battery_alert_outlined, color: Colors.redAccent),
                  title: const Text('Realme / ColorOS phones'),
                  subtitle: Text(
                    'These phones aggressively close background apps. Go to Settings > '
                    'Battery > App Battery Management and turn ON "Allow background '
                    'activity" and "Allow auto-launch" for this app.',
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.title, required this.granted, required this.onFix});

  final String title;
  final bool? granted;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final isGranted = granted == true;
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isGranted ? primary : Colors.redAccent).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isGranted ? Icons.check_circle : Icons.error_outline,
          color: isGranted ? primary : Colors.redAccent,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: isGranted
          ? Icon(Icons.check, color: primary)
          : FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                foregroundColor: Colors.redAccent,
              ),
              onPressed: onFix,
              child: const Text('Fix'),
            ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.7)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
