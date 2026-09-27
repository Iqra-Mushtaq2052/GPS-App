import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_scope.dart';
import '../../app.dart';
import '../../background/proximity_engine.dart';
import '../../core/native/native_proximity_bridge.dart';
import '../../core/prayer/hijri_service.dart';
import '../../core/prayer/prayer_tracker_service.dart';
import '../../data/db/app_database.dart';
import '../calendar/islamic_calendar_sheet.dart';
import '../mosque/add_mosque_page.dart';
import '../qibla/qibla_compass_page.dart';

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
  String? _selectedJamaatMosqueId;

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
      backgroundColor: isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ── Custom Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.nightlight_round, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Assalamu Alaikum',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      HijriService.formatHijriDate(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (_isImam && scope.auth.fullName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Imam: ${scope.auth.fullName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF59E0B), // Gold
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.settings, color: theme.colorScheme.onSurface),
                  onPressed: () => MainShell.jumpTo(context, 3),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Monitoring Card ──
            _GlassCard(
              borderColor: _monitoringEnabled ? const Color(0xFF10B981) : Colors.grey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (_monitoringEnabled ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.mosque,
                            color: _monitoringEnabled ? const Color(0xFF10B981) : Colors.grey,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Auto-Silent Monitoring',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _monitoringEnabled
                                    ? 'Active — silences your phone near saved mosques'
                                    : 'Paused — turn ON to enable auto-silent',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              StreamBuilder<List<Mosque>>(
                                stream: scope.mosqueRepository.watchAll(),
                                builder: (context, snapshot) {
                                  final count = snapshot.data?.length ?? 0;
                                  return Text(
                                    '$count mosques being monitored',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  );
                                },
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
                            activeThumbColor: const Color(0xFF10B981),
                            onChanged: _toggleMonitoring,
                          ),
                      ],
                    ),
                    if (!_locationServiceOn) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.gps_off, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'GPS is off. Phone location must be ON for auto-silence.',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Nearest Mosque Card ──
            StreamBuilder<ProximitySnapshot>(
              stream: scope.proximity.snapshots,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final insideReading = snapshot.data!.readings.where((r) => r.state == ZoneState.inside).firstOrNull;
                if (insideReading == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _GlassCard(
                    borderColor: const Color(0xFF10B981),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF10B981),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  insideReading.mosqueName,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Inside mosque radius',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          // Attempt to show prayer time if connected
                          FutureBuilder<Mosque?>(
                            future: scope.mosqueRepository.getById(insideReading.mosqueId),
                            builder: (context, mSnapshot) {
                              if (!mSnapshot.hasData) return const SizedBox.shrink();
                              final m = mSnapshot.data!;
                              final times = scope.sync.timesFor(m.supabaseId);
                              if (times == null) return const SizedBox.shrink();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Next Jamaat', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    times.fajr, // Defaulting to Fajr just to show, or could compute next
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Quick Stats Row ──
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<Mosque>>(
                    stream: scope.mosqueRepository.watchAll(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return _StatCard(title: 'Masajid', value: '$count', icon: Icons.mosque);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    title: 'GPS',
                    value: _locationServiceOn ? 'On' : 'Off',
                    icon: Icons.gps_fixed,
                    valueColor: _locationServiceOn ? const Color(0xFF10B981) : Colors.amber,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListenableBuilder(
                    listenable: scope.sync,
                    builder: (context, _) {
                      return _StatCard(
                        title: 'Live',
                        value: scope.sync.isLive ? 'Online' : 'Offline',
                        icon: Icons.cloud_sync,
                        valueColor: scope.sync.isLive ? const Color(0xFF10B981) : Colors.grey,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Prayer Times Card ──
            ListenableBuilder(
              listenable: scope.sync,
              builder: (context, _) {
                final connected = scope.sync.connectedMosques
                    .where((m) => scope.sync.timesFor(m.supabaseId) != null)
                    .toList();

                if (connected.isNotEmpty) {
                  final selected = connected.firstWhere(
                    (m) => m.supabaseId == _selectedJamaatMosqueId,
                    orElse: () => connected.first,
                  );
                  final times = scope.sync.timesFor(selected.supabaseId)!;

                  return _GlassCard(
                    borderColor: const Color(0xFFF59E0B), // Gold
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.access_time_filled, color: Color(0xFFF59E0B), size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Live Jamaat — ${selected.name}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (connected.length > 1)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.swap_vert, size: 20),
                                  onSelected: (id) => setState(() => _selectedJamaatMosqueId = id),
                                  itemBuilder: (_) => connected
                                      .map((m) => PopupMenuItem<String>(value: m.supabaseId!, child: Text(m.name)))
                                      .toList(),
                                )
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _JamaatTimeColumn(name: 'Fajr', time: times.fajr),
                              _JamaatTimeColumn(name: 'Zuhr', time: times.dhuhr),
                              _JamaatTimeColumn(name: 'Asr', time: times.asr),
                              _JamaatTimeColumn(name: 'Maghrib', time: times.maghrib),
                              _JamaatTimeColumn(name: 'Isha', time: times.isha),
                            ],
                          ),
                          if (times.jumuah != null && times.jumuah!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                'Jumuah: ${times.jumuah}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                              ),
                            )
                          ],
                        ],
                      ),
                    ),
                  );
                } else if (_todayTimes != null) {
                  return _PrayerTimesCard(
                    times: _todayTimes!,
                    completedPrayers: _completedPrayers,
                    onTogglePrayer: _togglePrayer,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 16),

            // ── Role-aware CTA Banner ──
            StreamBuilder<List<Mosque>>(
              stream: scope.mosqueRepository.watchAll(),
              builder: (context, snapshot) {
                final mosqueCount = snapshot.data?.length ?? 0;

                // IMAM: show register mosque CTA if no managed mosque yet
                if (_isImam) {
                  return ListenableBuilder(
                    listenable: scope.sync,
                    builder: (context, _) {
                      final managed = scope.sync.managedMosques;
                      if (managed.isNotEmpty) return const SizedBox.shrink();
                      return _HeroCTA(
                        icon: Icons.add_location_alt,
                        color: const Color(0xFFF59E0B),
                        title: 'Register Your Mosque',
                        subtitle: 'You haven\'t registered a mosque yet. Set up your mosque profile, prayer times, and share code.',
                        buttonLabel: 'Register Mosque Now',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddMosquePage()),
                        ),
                      );
                    },
                  );
                }

                // NAMAZI: show discover CTA when no mosques downloaded
                if (mosqueCount == 0) {
                  return _HeroCTA(
                    icon: Icons.travel_explore,
                    color: const Color(0xFF10B981),
                    title: 'Find Nearby Mosques',
                    subtitle: 'Search mosques near you, download them, and your phone will auto-silence when you arrive.',
                    buttonLabel: 'Open Masjid Store',
                    onTap: () => MainShell.jumpTo(context, 1),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 16),

            // ── Quick Actions ──
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                if (_isImam) ...[
                  _ActionCard(
                    title: 'Register Mosque',
                    subtitle: 'Add your mosque',
                    icon: Icons.add_location_alt,
                    color: const Color(0xFFF59E0B),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddMosquePage()),
                    ),
                  ),
                  _ActionCard(
                    title: 'My Mosque',
                    subtitle: 'Manage & announce',
                    icon: Icons.mosque,
                    color: const Color(0xFF10B981),
                    onTap: () => MainShell.jumpTo(context, 2),
                  ),
                ] else ...[
                  _ActionCard(
                    title: 'Discover',
                    subtitle: 'Find Mosques',
                    icon: Icons.travel_explore,
                    color: const Color(0xFF10B981),
                    onTap: () => MainShell.jumpTo(context, 1),
                  ),
                  _ActionCard(
                    title: 'My Masajid',
                    subtitle: 'Downloaded mosques',
                    icon: Icons.bookmark,
                    color: const Color(0xFF10B981),
                    onTap: () => MainShell.jumpTo(context, 2),
                  ),
                ],
                _ActionCard(
                  title: 'Calendar',
                  subtitle: 'Islamic Dates',
                  icon: Icons.calendar_month,
                  color: const Color(0xFFF59E0B),
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const IslamicCalendarSheet(),
                  ),
                ),
                _ActionCard(
                  title: 'Qibla',
                  subtitle: 'Compass',
                  icon: Icons.explore,
                  color: Colors.deepPurpleAccent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const QiblaCompassPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _JamaatTimeColumn extends StatelessWidget {
  final String name;
  final String time;

  const _JamaatTimeColumn({required this.name, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(time, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatCard({required this.title, required this.value, required this.icon, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor ?? Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface.withValues(alpha: 0.7) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
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

/// Prominent hero-style call-to-action card shown on home screen
/// when a key action is missing (e.g., 0 mosques for Namazi, or
/// no registered mosque for Imam).
class _HeroCTA extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  const _HeroCTA({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface.withValues(alpha: 0.8) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
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
                  'Azaan Times (calculated)',
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
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.2) // Highlight next in gold
                                : (isDone
                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                    : (isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isNext
                                  ? const Color(0xFFF59E0B)
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
                                    : (isNext ? const Color(0xFFF59E0B) : theme.colorScheme.primary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isNext || isDone ? FontWeight.bold : FontWeight.normal,
                                  color: isNext
                                      ? const Color(0xFFF59E0B)
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
