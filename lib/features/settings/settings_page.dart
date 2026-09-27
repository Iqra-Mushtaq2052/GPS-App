import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../background/proximity_engine.dart';
import '../../core/auth/auth_service.dart';
import '../../core/ringer/ringer_service.dart';
import '../auth/imam_auth_page.dart';
import '../diagnostics/diagnostics_page.dart';
import '../mosque/add_mosque_page.dart';
import '../mosque/mosque_detail_page.dart';
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
  bool _notifAnnouncements = true;
  bool _notifPrayerTimes = true;
  String? _testSilenceResult;
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
    final notifAnn = prefs.getBool('pref_notif_announcements') ?? true;
    final notifPrayer = prefs.getBool('pref_notif_prayer_times') ?? true;

    // Optionally check if imam is signed in to fetch managed mosques
    if (scope.auth.isSignedIn && scope.auth.isApprovedImam) {
      if (scope.sync.managedMosques.isEmpty) {
        scope.sync.refreshManaged();
      }
    }

    if (mounted) {
      setState(() {
        _backgroundLocationGranted = bgLocation;
        _batteryOptimizationIgnored = batteryOk;
        _ignorePrayerTime = ignorePrayerTime;
        _notifAnnouncements = notifAnn;
        _notifPrayerTimes = notifPrayer;
      });
    }
  }

  Future<void> _logout() async {
    final scope = AppScope.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await scope.auth.signOut();
      scope.sync.clearManaged();
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
        body: 'This is a test notification. Ringer is now silent — restore using "Restore Ringer".',
      );
    }
    if (!mounted) return;
    setState(() {
      _testSilenceResult = switch (result) {
        RingerActionResult.changed =>
          'Success — phone is NOW silent and will stay silent. Check it yourself, then press "Restore Ringer".',
        RingerActionResult.alreadyInDesiredState =>
          'Phone was already silent. Make the ringer normal first, then test.',
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
        RingerActionResult.notOurs => 'App did not change the ringer (or you changed it yourself) — nothing done.',
        RingerActionResult.alreadyInDesiredState => 'Ringer was already in the correct state.',
        RingerActionResult.noPermission => 'Failed — issue changing ringer mode.',
      };
    });
  }

  Widget _buildImamStatusBadge(ImamStatus status) {
    Color color;
    String label;
    switch (status) {
      case ImamStatus.approved:
        color = const Color(0xFF10B981);
        label = 'Approved Imam';
        break;
      case ImamStatus.pending:
        color = const Color(0xFFF59E0B);
        label = 'Pending Approval';
        break;
      case ImamStatus.rejected:
        color = Colors.redAccent;
        label = 'Rejected';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown Status';
        break;
    }
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitleColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final dividerColor = theme.dividerColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: isDark ? const Color(0xFF0D1117) : theme.colorScheme.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Account Section ──
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text('Account', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (scope.auth.isSignedIn)
            _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                          child: Icon(Icons.person, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(scope.auth.fullName ?? 'Imam', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(scope.auth.email ?? '', style: TextStyle(color: subtitleColor, fontSize: 12)),
                              _buildImamStatusBadge(scope.auth.status),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_location_alt),
                      label: const Text('Register My Mosque'),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const AddMosquePage(),
                        ));
                      },
                    ),
                    const SizedBox(height: 8),
                    if (scope.auth.isApprovedImam)
                      ListenableBuilder(
                        listenable: scope.sync,
                        builder: (context, _) {
                          return OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981)),
                            ),
                            icon: const Icon(Icons.mosque),
                            label: const Text('My Managed Mosques'),
                            onPressed: () {
                              final managed = scope.sync.managedMosques;
                              if (managed.isNotEmpty) {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => MosqueDetailPage(cloudMosque: managed.first),
                                ));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No managed mosques found. Pull to refresh home.')),
                                );
                              }
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                        foregroundColor: Colors.redAccent,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
            )
          else
            _GlassCard(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                title: const Text('Not signed in'),
                subtitle: const Text('Imam or Committee Member?'),
                trailing: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
                  child: const Text('Sign in as Imam'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImamAuthPage()));
                    _refreshStatuses();
                  },
                ),
              ),
            ),
          const SizedBox(height: 24),

          // ── Theme Section ──
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
                        style: SegmentedButton.styleFrom(
                          selectedForegroundColor: Colors.white,
                          selectedBackgroundColor: const Color(0xFF10B981),
                        ),
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

          // ── Notifications Section ──
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text('Notifications', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _GlassCard(
            child: Column(
              children: [
                SwitchListTile(
                  activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.5),
                  secondary: const Icon(Icons.campaign),
                  title: const Text('Announcements'),
                  subtitle: const Text('Receive notifications for masjid notices.'),
                  value: _notifAnnouncements,
                  onChanged: (val) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('pref_notif_announcements', val);
                    setState(() => _notifAnnouncements = val);
                  },
                ),
                Divider(height: 1, color: dividerColor),
                SwitchListTile(
                  activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.5),
                  secondary: const Icon(Icons.access_time),
                  title: const Text('Prayer Time Updates'),
                  subtitle: const Text('Receive notifications when jamaat times change.'),
                  value: _notifPrayerTimes,
                  onChanged: (val) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('pref_notif_prayer_times', val);
                    setState(() => _notifPrayerTimes = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Permissions ──
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

          // ── Testing Section ──
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text('Testing & Diagnostics', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _GlassCard(
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('Developer & Testing Tools'),
                children: [
                  Divider(height: 1, color: dividerColor),
                  SwitchListTile(
                    title: const Text('Ignore prayer-time check'),
                    subtitle: Text(
                      'Silences upon entry regardless of prayer times.',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    value: _ignorePrayerTime,
                    onChanged: (value) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(prefsIgnorePrayerTimeKey, value);
                      setState(() => _ignorePrayerTime = value);
                    },
                  ),
                  Divider(height: 1, color: dividerColor),
                  ListTile(
                    leading: Icon(Icons.volume_off, color: theme.colorScheme.secondary),
                    title: const Text('Test Silence Now', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      _testSilenceResult ?? 'Force test silent-mode permission without waiting.',
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
                  ListTile(
                    leading: const Icon(Icons.monitor_heart),
                    title: const Text('Open Diagnostics Page'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiagnosticsPage())),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── About Section ──
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text('About', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _GlassCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Masjid GPS App'),
                  subtitle: const Text('Version 1.0.0'),
                ),
                Divider(height: 1, color: dividerColor),
                ListTile(
                  leading: const Icon(Icons.gps_fixed),
                  title: const Text('GPS Offline Mode'),
                  subtitle: Text(
                    'Your GPS coordinates are processed entirely on-device and never sent to servers.',
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                ),
                Divider(height: 1, color: dividerColor),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Open Source / GitHub'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
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
        color: isDark ? theme.colorScheme.surface.withValues(alpha: 0.7) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
