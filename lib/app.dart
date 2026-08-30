import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/permission_onboarding_page.dart';

class GpsApp extends StatelessWidget {
  const GpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _StartupGate(),
    );
  }
}

/// Decides whether to show the permission-onboarding flow or go straight
/// to the home screen, based on whether location permissions were already
/// granted in a previous run.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  Future<bool>? _readyFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _readyFuture ??= _prepare();
  }

  Future<bool> _prepare() async {
    final scope = AppScope.of(context);
    await scope.notifications.init();
    final foreground = await scope.permissions.hasForegroundLocation();
    final background = await scope.permissions.hasBackgroundLocation();
    return foreground && background;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _readyFuture!,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data! ? const HomePage() : const PermissionOnboardingPage();
      },
    );
  }
}
