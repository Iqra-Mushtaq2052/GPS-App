import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_scope.dart';
import '../../background/proximity_engine.dart';
import '../../core/ringer/ringer_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _dndGranted;
  bool? _backgroundLocationGranted;
  bool? _batteryOptimizationIgnored;
  bool _ignorePrayerTime = true;
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
    final dnd = await scope.ringer.hasDoNotDisturbAccess();
    final bgLocation = await scope.permissions.hasBackgroundLocation();
    final batteryOk = await scope.permissions.isIgnoringBatteryOptimizations();
    final prefs = await SharedPreferences.getInstance();
    final ignorePrayerTime = prefs.getBool(prefsIgnorePrayerTimeKey) ?? true;
    if (mounted) {
      setState(() {
        _dndGranted = dnd;
        _backgroundLocationGranted = bgLocation;
        _batteryOptimizationIgnored = batteryOk;
        _ignorePrayerTime = ignorePrayerTime;
      });
    }
  }

  /// Silences and then STAYS silent. An earlier version auto-restored after
  /// three seconds, which looked exactly like "the OS is undoing it" — it
  /// was this code. Restoring is now an explicit, separate action.
  /// Silences and then STAYS silent. An earlier version auto-restored after
  /// three seconds, which looked exactly like "the OS is undoing it" — it
  /// was this code. Restoring is now an explicit, separate action.
  Future<void> _testSilenceNow() async {
    final scope = AppScope.of(context);
    setState(() => _testSilenceResult = null);
    final result = await scope.ringer.silenceForPrayer();
    if (result == RingerActionResult.changed) {
      await scope.notifications.show(
        title: 'Test: phone silent kar diya',
        body: 'Ye test notification hai. Ringer ab silent hai — '
            '"Ringer Wapas Karein" se restore karein.',
      );
    }
    if (!mounted) return;
    setState(() {
      _testSilenceResult = switch (result) {
        RingerActionResult.changed =>
          'Kamyab — phone AB silent hai aur silent hi rahega. Khud check '
              'karein, phir "Ringer Wapas Karein" dabayein.',
        RingerActionResult.alreadyInDesiredState =>
          'Phone pehle se hi silent tha — kuch badla nahi. Pehle ringer '
              'normal karein, phir test karein.',
        RingerActionResult.noPermission =>
          'Nakaam — Do Not Disturb access grant nahi hai (ya OS ne wapas '
              'le li hai). Upar "Do Not Disturb Access" theek karein.',
        RingerActionResult.notOurs => 'Kuch tabdeeli nahi hui.',
      };
    });
  }

  Future<void> _restoreRinger() async {
    final scope = AppScope.of(context);
    final result = await scope.ringer.restorePreviousMode();
    if (!mounted) return;
    setState(() {
      _testSilenceResult = switch (result) {
        RingerActionResult.changed => 'Ringer wapas normal kar diya gaya.',
        RingerActionResult.notOurs =>
          'App ne ringer badla hi nahi tha (ya aap ne khud badal diya) — '
              'is liye kuch nahi kiya gaya.',
        RingerActionResult.alreadyInDesiredState =>
          'Ringer pehle se hi theek tha.',
        RingerActionResult.noPermission =>
          'Do Not Disturb access nahi hai — ringer badla nahi ja saka.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _StatusTile(
            title: 'Background Location',
            granted: _backgroundLocationGranted,
            onFix: () async {
              await scope.permissions.requestBackgroundLocation();
              _refreshStatuses();
            },
          ),
          _StatusTile(
            title: 'Do Not Disturb Access (phone silent karne ke liye)',
            granted: _dndGranted,
            onFix: () async {
              await scope.ringer.openDoNotDisturbSettings();
              _refreshStatuses();
            },
          ),
          _StatusTile(
            title: 'Battery Optimization Ignored',
            granted: _batteryOptimizationIgnored,
            onFix: () async {
              await scope.permissions.requestIgnoreBatteryOptimizations();
              _refreshStatuses();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.volume_off),
            title: const Text('Test Silence Now'),
            subtitle: Text(_testSilenceResult ??
                'Range ka intezar kiye bina abhi silent-mode permission test '
                    'karein. Phone silent hi rahega jab tak aap khud wapas na karein.'),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _restoreRinger,
                child: const Text('Ringer Wapas Karein'),
              ),
              FilledButton(
                onPressed: _testSilenceNow,
                child: const Text('Silent Karein'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Testing Mode: Prayer-time check ignore karein'),
            subtitle: const Text(
              'ON hone par geofence ke andar aate hi silent ho jayega, chahe '
              'namaz ka waqt ho ya na ho — sirf boundary/range test karne ke '
              'liye. Range theek se kaam karne ke baad ise OFF kar dein.',
            ),
            value: _ignorePrayerTime,
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(prefsIgnorePrayerTimeKey, value);
              setState(() => _ignorePrayerTime = value);
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Entry confirmation delay'),
            subtitle: Text(
              'Chhoti radius (20-60m) par GPS thoda "jitter" karta hai, is '
              'liye entry par turant nahi — ~20 second tak lagatar andar '
              'rehne ke baad hi confirm hoker silent hota hai. Ye jaan-boojh '
              'kar hai taake bahar-andar ki galat notification na aaye.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.battery_alert_outlined),
            title: Text('Realme / ColorOS phones'),
            subtitle: Text(
              'Ye phones background apps ko aggressively band kar dete hain. '
              'Settings > Battery > App Battery Management mein is app ke '
              'liye "Allow background activity" aur "Allow auto-launch" ON '
              'karein, aur Startup Manager mein bhi allow karein — warna '
              'silent-mode kabhi kabhi kaam karna band kar dega.',
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
    return ListTile(
      leading: Icon(
        isGranted ? Icons.check_circle : Icons.error_outline,
        color: isGranted ? Colors.green : Colors.orange,
      ),
      title: Text(title),
      trailing: isGranted
          ? null
          : TextButton(onPressed: onFix, child: const Text('Theek Karein')),
    );
  }
}
