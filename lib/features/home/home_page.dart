import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_scope.dart';
import '../../data/db/app_database.dart';
import '../diagnostics/diagnostics_page.dart';
import '../mosque/mosque_list_page.dart';
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
    if (mosques.isNotEmpty) {
      final first = mosques.first;
      _todayTimes = scope.prayerTimes.todayTimes(first.latitude, first.longitude);
    }

    // Resume monitoring across app restarts if it was left on.
    if (enabled && serviceOn && !scope.proximity.isRunning) {
      await scope.proximity.start();
    }

    if (mounted) {
      setState(() {
        _monitoringEnabled = enabled;
        _locationServiceOn = serviceOn;
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
            _error = 'Phone ka Location (GPS) band hai — pehle usay ON karein.';
          });
          return;
        }
        await scope.proximity.refreshMosques();
        await scope.proximity.start();
      } else {
        await scope.proximity.stop();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsMonitoringEnabledKey, value);
      setState(() {
        _monitoringEnabled = value;
        _locationServiceOn = true;
      });
    } catch (e) {
      setState(() => _error = 'Monitoring start nahi ho saki: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.monitor_heart_outlined),
            tooltip: 'Live Diagnostics',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiagnosticsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_locationServiceOn)
            const Card(
              color: Color(0xFFFFEBEE),
              child: ListTile(
                leading: Icon(Icons.gps_off, color: Colors.red),
                title: Text('Location (GPS) band hai'),
                subtitle: Text(
                  'Ye app bina internet ke chal sakti hai, lekin GPS ka ON hona '
                  'lazmi hai — warna location bilkul nahi milegi.',
                ),
              ),
            ),
          Card(
            child: SwitchListTile(
              title: const Text('Masjid Monitoring'),
              subtitle: Text(_monitoringEnabled
                  ? 'Active — saved masjidon ke paas aane par phone silent hoga'
                  : 'Band hai'),
              value: _monitoringEnabled,
              onChanged: _busy ? null : _toggleMonitoring,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('Live Diagnostics'),
              subtitle: const Text(
                'GPS accuracy aur masjid se asal doori live dekhein — '
                'range ka masla yahin se samajh aayega.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiagnosticsPage()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_todayTimes != null) _PrayerTimesCard(times: _todayTimes!),
          const SizedBox(height: 8),
          StreamBuilder<List<Mosque>>(
            stream: scope.mosqueRepository.watchAll(),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.mosque),
                  title: const Text('Saved Masjidein'),
                  subtitle: Text('$count masjid save hain'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MosqueListPage()),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PrayerTimesCard extends StatelessWidget {
  const _PrayerTimesCard({required this.times});

  final Map<String, DateTime> times;

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aaj Ke Namaz Waqt', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...times.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(e.key), Text(_fmt(e.value))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
