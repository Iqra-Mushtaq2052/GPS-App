import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../home/home_page.dart';

/// Requests every permission the background silent-trigger feature needs,
/// one at a time (Android best practice — bundling requests together
/// increases rejection rates). Background location must be requested only
/// after foreground location is already granted.
///
/// The "Do Not Disturb access" step in particular does NOT auto-advance
/// after opening system settings: that intent returns immediately whether
/// or not the user actually granted anything, and blindly moving on was
/// the root cause of "notification shows but phone never goes silent" —
/// the app proceeded assuming access was granted when it wasn't. This page
/// re-checks on resume and only advances once access is confirmed (or the
/// user explicitly skips).
class PermissionOnboardingPage extends StatefulWidget {
  const PermissionOnboardingPage({super.key});

  @override
  State<PermissionOnboardingPage> createState() =>
      _PermissionOnboardingPageState();
}

enum _Step {
  foregroundLocation,
  backgroundLocation,
  doNotDisturb,
  batteryOptimization,
  notifications,
  done,
}

class _PermissionOnboardingPageState extends State<PermissionOnboardingPage>
    with WidgetsBindingObserver {
  _Step _step = _Step.foregroundLocation;
  bool _busy = false;
  bool? _dndGrantedNow;

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _step == _Step.doNotDisturb) {
      _recheckDnd();
    }
  }

  Future<void> _recheckDnd() async {
    final scope = AppScope.of(context);
    final granted = await scope.ringer.hasDoNotDisturbAccess();
    if (mounted) setState(() => _dndGrantedNow = granted);
  }

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
          setState(() => _step = _Step.doNotDisturb);
        case _Step.doNotDisturb:
          if (_dndGrantedNow != true) {
            await scope.ringer.openDoNotDisturbSettings();
            // Lifecycle callback re-checks when the user returns from
            // Settings; do not advance from here.
            return;
          }
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

  ({String title, String body, String cta}) get _content {
    switch (_step) {
      case _Step.foregroundLocation:
        return (
          title: 'Location Permission',
          body: 'App ko masjid ke qareeb hone ki tasdeeq karne ke liye '
              'aapki location chahiye.',
          cta: 'Location Permission Dein',
        );
      case _Step.backgroundLocation:
        return (
          title: 'Background Location ("Allow all the time")',
          body: 'Agli screen par "Allow all the time" chunein — is ke bina '
              'app band hone ke baad masjid ke paas aana detect nahi kar sakega.',
          cta: 'Background Location Dein',
        );
      case _Step.doNotDisturb:
        final granted = _dndGrantedNow == true;
        return (
          title: 'Do Not Disturb Access',
          body: granted
              ? 'Do Not Disturb access mil chuki hai — phone silent karna '
                  'kaam karega. Aage barhein.'
              : 'Phone ko silent karne ke liye Android "Do Not Disturb" '
                  'access chahiye. Agli screen par is app ko allow karein — '
                  'wapas aane par yahan khud check ho jayega. (Kuch phones, '
                  'jaise Realme/ColorOS, ye permission khud-ba-khud waqt ke '
                  'sath hata dete hain — agar silent kaam karna band ho jaye '
                  'to Settings mein dobara check karein.)',
          cta: granted ? 'Aage Barhein' : 'Settings Kholein',
        );
      case _Step.batteryOptimization:
        return (
          title: 'Battery Optimization Ignore Karein',
          body: 'Isse Android app ko background mein sote waqt (Doze mode) '
              'band karne se rokega.',
          cta: 'Ijazat Dein',
        );
      case _Step.notifications:
        return (
          title: 'Notifications',
          body: 'Masjid ke paas aane/jaane par alert dikhane ke liye '
              'notification permission chahiye.',
          cta: 'Notification Permission Dein',
        );
      case _Step.done:
        return (
          title: 'Tayyar!',
          body: 'Saari permissions set ho gayi hain.',
          cta: 'Aage Barhein',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    final stepIndex = _Step.values.indexOf(_step) + 1;
    final onDndStep = _step == _Step.doNotDisturb;
    return Scaffold(
      appBar: AppBar(title: const Text('Setup')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Step $stepIndex / ${_Step.values.length}',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            Text(content.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(content.body),
            if (onDndStep) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _dndGrantedNow == true ? Icons.check_circle : Icons.error_outline,
                    color: _dndGrantedNow == true ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(_dndGrantedNow == true ? 'Granted' : 'Abhi tak granted nahi'),
                  const Spacer(),
                  TextButton(onPressed: _recheckDnd, child: const Text('Recheck')),
                ],
              ),
              if (_dndGrantedNow != true)
                TextButton(
                  onPressed: () => setState(() => _step = _Step.batteryOptimization),
                  child: const Text('Filhal Skip Karein (baad mein Settings se theek karein)'),
                ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _advance,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(content.cta),
            ),
          ],
        ),
      ),
    );
  }
}
