import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_scope.dart';
import '../../core/native/native_proximity_bridge.dart';
import '../../core/prayer/hijri_service.dart';
import '../../core/prayer/prayer_tracker_service.dart';
import '../../data/db/app_database.dart';
import '../announcements/notice_board_page.dart';
import '../calendar/islamic_calendar_sheet.dart';
import '../diagnostics/diagnostics_page.dart';
import '../map/mosque_map_page.dart';
import '../mosque/discover_mosques_page.dart';
import '../mosque/mosque_list_page.dart';
import '../prayer_tracker/prayer_tracker_page.dart';
import '../qibla/qibla_map_page.dart';
import '../role/role_selection_page.dart';
import '../settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _prefsMonitoringEnabledKey = 'monitoring_enabled';
  bool _monitoringEnabled = false;
  bool _busy = false;
  bool _locationServiceOn = true;
  Map<String, DateTime>? _todayTimes;
  bool _loadStarted = false;
  String? _error;
  Set<String> _completedPrayers = {};
  StreamSubscription? _mosquesSubscription;
  bool _isImam = false;

  @override
  void dispose() {
    _mosquesSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadStarted) {
      _loadStarted = true;
      _loadState();
    }
  }

  Future<void> _loadState() async {
    final scope = AppScope.of(context);
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefsMonitoringEnabledKey) ?? false;
    final serviceOn = await scope.location.isLocationServiceEnabled();
    final mosques = await scope.mosqueRepository.watchAll().first;
    final isImam = await scope.roleService.isImam();

    _mosquesSubscription ??= scope.mosqueRepository.watchAll().listen((mosquesList) {
      NativeProximityBridge.syncMosques(mosquesList);
    });

    if (mosques.isNotEmpty) {
      final first = mosques.first;
      _todayTimes = scope.prayerTimes.todayTimes(first.latitude, first.longitude);
    } else {
      _todayTimes = scope.prayerTimes.todayTimes(30.7460, 73.3379);
    }

    final completed = await PrayerTrackerService.getCompletedPrayers();

    if (enabled && serviceOn) {
      if (!scope.proximity.isRunning) {
        await scope.proximity.start();
      }
      await NativeProximityBridge.startNativeService(mosques);
    }

    if (mounted) {
      setState(() {
        _monitoringEnabled = enabled;
        _locationServiceOn = serviceOn;
        _completedPrayers = completed;
        _isImam = isImam;
      });
    }
  }

  Future<void> _toggleMonitoring(bool value) async {
    final scope = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (value) {
        if (!await scope.location.isLocationServiceEnabled()) {
          setState(() {
            _locationServiceOn = false;
            _error = 'Phone Location (GPS) is turned off — please turn it ON first.';
          });
          return;
        }
        await scope.proximity.refreshMosques();
        await scope.proximity.start();
        final mosques = await scope.mosqueRepository.watchAll().first;
        await NativeProximityBridge.startNativeService(mosques);
      } else {
        await scope.proximity.stop();
        await NativeProximityBridge.stopNativeService();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsMonitoringEnabledKey, value);

      setState(() {
        _monitoringEnabled = value;
        _locationServiceOn = true;
      });
    } catch (e) {
      setState(() => _error = 'Could not start monitoring: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePrayer(String prayerName) async {
    final updated = await PrayerTrackerService.togglePrayer(prayerName);
    if (mounted) {
      setState(() {
        _completedPrayers = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF059669), Colors.transparent]
                  : [const Color(0xFF059669).withValues(alpha: 0.2), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.mosque, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 8),
            const Text(
              'Masjid GPS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_month, color: theme.colorScheme.secondary),
            tooltip: 'Islamic Calendar & Events',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const IslamicCalendarSheet(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.swap_horiz, color: theme.colorScheme.secondary),
            tooltip: 'Switch Role (Imam / User)',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.monitor_heart_outlined, color: theme.colorScheme.onSurface),
            tooltip: 'Live Diagnostics',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => DraggableScrollableSheet(
                initialChildSize: 0.9,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                builder: (_, controller) => Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: DiagnosticsPage(scrollController: controller),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [Color(0xFF161B22), Color(0xFF0D1117)],
                ),
              )
            : null,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // ── Dedicated Interactive Islamic Calendar Card ──
              _GlassCard(
                borderColor: theme.colorScheme.secondary,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const IslamicCalendarSheet(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.calendar_month, color: theme.colorScheme.secondary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Today\'s Hijri Date:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Auto Daily',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                HijriService.formatHijriDate(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Open Calendar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, size: 12, color: theme.colorScheme.secondary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // GPS Off Alert Banner
              if (!_locationServiceOn)
                _GlassCard(
                  borderColor: Colors.redAccent,
                  child: ListTile(
                    leading: const Icon(Icons.gps_off, color: Colors.redAccent),
                    title: Text('Location (GPS) is off', style: TextStyle(color: theme.colorScheme.onSurface)),
                    subtitle: Text(
                      'GPS must be ON for auto-silence near mosques.',
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ),
                ),
              if (!_locationServiceOn) const SizedBox(height: 12),

              // ── Live Monitoring Switch Card ──
              _GlassCard(
                borderColor: _monitoringEnabled ? theme.colorScheme.primary : Colors.grey,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _monitoringEnabled ? const Color(0xFF10B981) : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mosque Auto-Silent',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _monitoringEnabled
                                  ? 'Active — phone silences near saved mosques'
                                  : 'Paused — turn ON to enable auto-silent',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_busy)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      else
                        Switch(
                          value: _monitoringEnabled,
                          activeColor: theme.colorScheme.primary,
                          onChanged: _toggleMonitoring,
                        ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),

              // ── Today's Prayer Times Grid ──
              if (_todayTimes != null)
                _PrayerTimesCard(
                  times: _todayTimes!,
                  completedPrayers: _completedPrayers,
                  onTogglePrayer: _togglePrayer,
                ),
              const SizedBox(height: 16),

              // ── Action Grid (2x3 Layout) ──
              Row(
                children: [
                  Expanded(
                    child: _GlassCard(
                      borderColor: theme.colorScheme.secondary,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        leading: Icon(Icons.explore, color: theme.colorScheme.secondary, size: 22),
                        title: const Text('Qibla Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('Direct Kaaba line', style: TextStyle(fontSize: 10)),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const QiblaMapPage()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GlassCard(
                      borderColor: theme.colorScheme.primary,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        leading: Icon(Icons.campaign, color: theme.colorScheme.primary, size: 22),
                        title: const Text('Notice Board', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('Announcements', style: TextStyle(fontSize: 10)),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const NoticeBoardPage()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _GlassCard(
                      borderColor: theme.colorScheme.primary,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        leading: Icon(Icons.map, color: theme.colorScheme.primary, size: 22),
                        title: const Text('Mosque Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('1km / 3km radius', style: TextStyle(fontSize: 10)),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MosqueMapPage()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StreamBuilder<List<Mosque>>(
                      stream: scope.mosqueRepository.watchAll(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return _GlassCard(
                          borderColor: theme.colorScheme.secondary,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            leading: Icon(Icons.mosque, color: theme.colorScheme.secondary, size: 22),
                            title: Text(
                              _isImam ? 'Manage Mosques' : 'Joined Mosques',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(
                              _isImam ? '$count managed' : '$count joined',
                              style: const TextStyle(fontSize: 10),
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const MosqueListPage()),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _GlassCard(
                borderColor: theme.colorScheme.primary,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  leading: Icon(Icons.checklist_rtl, color: theme.colorScheme.primary, size: 22),
                  title: const Text('Namaz Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Daily & Weekly Log', style: TextStyle(fontSize: 10)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrayerTrackerPage()),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Discover Nearby Mosques Hero Banner ──
              _GlassCard(
                borderColor: theme.colorScheme.primary,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.travel_explore, color: Color(0xFF10B981), size: 24),
                  ),
                  title: Text(
                    _isImam ? 'Discover & Register Mosques' : 'Find Mosques Nearby',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    _isImam
                        ? 'Auto-detect real masjids to claim & set prayer times'
                        : 'See nearby masjids & join via Imam\'s Share Code',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DiscoverMosquesPage()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _GlassCard({required this.child, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface.withValues(alpha: 0.7) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _PrayerTimesCard extends StatelessWidget {
  final Map<String, DateTime> times;
  final Set<String> completedPrayers;
  final Function(String) onTogglePrayer;

  const _PrayerTimesCard({
    required this.times,
    required this.completedPrayers,
    required this.onTogglePrayer,
  });

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String? _nextPrayer() {
    final now = DateTime.now();
    for (final entry in times.entries) {
      if (entry.value.isAfter(now)) {
        return entry.key;
      }
    }
    return times.keys.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final next = _nextPrayer();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time_filled, color: theme.colorScheme.secondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Today\'s Prayer Times',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  'Quick Check',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 32) / 5;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: times.entries.map((entry) {
                    final name = entry.key;
                    final time = entry.value;
                    final isNext = name == next;
                    final isDone = completedPrayers.contains(name);

                    return SizedBox(
                      width: itemWidth,
                      child: InkWell(
                        onTap: () => onTogglePrayer(name),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                          decoration: BoxDecoration(
                            color: isNext
                                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                : (isDone
                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                    : (isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isNext
                                  ? theme.colorScheme.primary
                                  : (isDone ? const Color(0xFF10B981) : Colors.transparent),
                              width: isNext ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDone ? Icons.check_circle : (isNext ? Icons.star : Icons.brightness_5),
                                size: 16,
                                color: isDone
                                    ? const Color(0xFF10B981)
                                    : (isNext ? theme.colorScheme.secondary : theme.colorScheme.primary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isNext || isDone ? FontWeight.bold : FontWeight.normal,
                                  color: isNext
                                      ? theme.colorScheme.secondary
                                      : (isDone
                                          ? const Color(0xFF10B981)
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.8)),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTime(time),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
