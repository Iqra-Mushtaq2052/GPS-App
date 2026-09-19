import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../home/home_page.dart';

class PermissionOnboardingPage extends StatefulWidget {
  const PermissionOnboardingPage({super.key});

  @override
  State<PermissionOnboardingPage> createState() =>
      _PermissionOnboardingPageState();
}

enum _Step {
  foregroundLocation,
  backgroundLocation,
  batteryOptimization,
  notifications,
  done,
}

class _PermissionOnboardingPageState extends State<PermissionOnboardingPage>
    with WidgetsBindingObserver {
  _Step _step = _Step.foregroundLocation;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Future<void> _advance() async {
    final scope = AppScope.of(context);
    setState(() => _busy = true);
    try {
      switch (_step) {
        case _Step.foregroundLocation:
          await scope.permissions.requestForegroundLocation();
          setState(() => _step = _Step.backgroundLocation);
        case _Step.backgroundLocation:
          await scope.permissions.requestBackgroundLocation();
          setState(() => _step = _Step.batteryOptimization);
        case _Step.batteryOptimization:
          if (!await scope.permissions.isIgnoringBatteryOptimizations()) {
            await scope.permissions.requestIgnoreBatteryOptimizations();
          }
          setState(() => _step = _Step.notifications);
        case _Step.notifications:
          await scope.permissions.requestNotifications();
          setState(() => _step = _Step.done);
        case _Step.done:
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ({String title, String body, String cta, IconData icon, Color color}) get _content {
    switch (_step) {
      case _Step.foregroundLocation:
        return (
          title: 'Location Permission',
          body: 'The app needs your location to confirm when you are near a mosque. This is required for the app to work properly.',
          cta: 'Grant Location Permission',
          icon: Icons.location_on,
          color: const Color(0xFF10B981),
        );
      case _Step.backgroundLocation:
        return (
          title: 'Background Location',
          body: 'Select "Allow all the time" on the next screen — without this, the app will not detect when you are near a mosque after it is closed.',
          cta: 'Grant Background Location',
          icon: Icons.my_location,
          color: const Color(0xFFF59E0B),
        );
      case _Step.batteryOptimization:
        return (
          title: 'Battery Optimization',
          body: 'This prevents Android from closing the app in the background while sleeping (Doze mode). Be sure to "Allow".',
          cta: 'Grant Permission',
          icon: Icons.battery_charging_full,
          color: const Color(0xFF10B981),
        );
      case _Step.notifications:
        return (
          title: 'Notifications',
          body: 'Notification permission is required to show alerts when entering/leaving near a mosque.',
          cta: 'Grant Notification Permission',
          icon: Icons.notifications_active,
          color: const Color(0xFFF59E0B),
        );
      case _Step.done:
        return (
          title: 'Ready!',
          body: 'All permissions have been set up. The app is ready to use.',
          cta: 'Let\'s Begin',
          icon: Icons.check_circle,
          color: const Color(0xFF10B981),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    final totalSteps = _Step.values.length;
    final currentStepIndex = _Step.values.indexOf(_step);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF059669), Color(0xFF0D1117)],
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    totalSteps,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == currentStepIndex ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index <= currentStepIndex
                            ? const Color(0xFF10B981)
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 64),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: content.color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: content.color.withValues(alpha: 0.3), width: 2),
                        ),
                        child: Icon(
                          content.icon,
                          size: 80,
                          color: content.color,
                        ),
                      ),
                      const SizedBox(height: 48),
                      Text(
                        content.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        content.body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _busy ? null : _advance,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          content.cta,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
