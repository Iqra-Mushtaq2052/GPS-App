import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'core/native/native_proximity_bridge.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/permission_onboarding_page.dart';
import 'features/role/role_selection_page.dart';

/// ─── Theme Notifier ───────────────────────────────────────────────
/// Manages Light / Dark / System theme mode, persisted in SharedPreferences.
class ThemeNotifier extends ChangeNotifier {
  static const _prefsKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Call once at startup to load the saved preference.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored != null) {
      _mode = ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

/// Singleton so every widget can access it without InheritedWidget noise.
final themeNotifier = ThemeNotifier();

/// ─── Shared colors ────────────────────────────────────────────────
const _emerald = Color(0xFF10B981);
const _emeraldDark = Color(0xFF059669);
const _gold = Color(0xFFF59E0B);
const _darkBg = Color(0xFF0D1117);
const _darkSurface = Color(0xFF161B22);

/// ─── Dark Theme ───────────────────────────────────────────────────
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: _darkBg,
  colorScheme: const ColorScheme.dark(
    primary: _emerald,
    secondary: _gold,
    surface: _darkSurface,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    iconTheme: IconThemeData(color: _emerald),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  cardTheme: CardThemeData(
    color: _darkSurface.withValues(alpha: 0.8),
    elevation: 8,
    shadowColor: Colors.black45,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.selected)) return _emerald;
      return Colors.grey;
    }),
    trackColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.selected)) {
        return _emeraldDark.withValues(alpha: 0.5);
      }
      return Colors.grey.withValues(alpha: 0.3);
    }),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _emerald,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _emerald,
      side: const BorderSide(color: _emerald),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  listTileTheme: const ListTileThemeData(iconColor: _emerald),
  dividerColor: Colors.white10,
  useMaterial3: true,
);

/// ─── Light Theme ──────────────────────────────────────────────────
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF5F5F0),
  colorScheme: const ColorScheme.light(
    primary: _emerald,
    secondary: _gold,
    surface: Colors.white,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Color(0xFF1A1A2E),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    iconTheme: IconThemeData(color: _emeraldDark),
    titleTextStyle: TextStyle(
      color: Color(0xFF1A1A2E),
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 4,
    shadowColor: Colors.black12,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.selected)) return _emerald;
      return Colors.grey;
    }),
    trackColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.selected)) {
        return _emerald.withValues(alpha: 0.3);
      }
      return Colors.grey.withValues(alpha: 0.2);
    }),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _emerald,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _emeraldDark,
      side: const BorderSide(color: _emeraldDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),
  listTileTheme: const ListTileThemeData(iconColor: _emeraldDark),
  dividerColor: Colors.grey.shade200,
  useMaterial3: true,
);

/// ─── App Widget ───────────────────────────────────────────────────
class GpsApp extends StatelessWidget {
  const GpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        return MaterialApp(
          title: 'GPS App',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeNotifier.mode,
          home: const _StartupGate(),
        );
      },
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
  Future<_StartupResult>? _readyFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _readyFuture ??= _prepare();
  }

  Future<_StartupResult> _prepare() async {
    // Load persisted theme preference.
    await themeNotifier.load();

    // Check if role has been selected
    if (!mounted) return _StartupResult.ready;
    final scope = AppScope.of(context);
    final hasRole = await scope.roleService.hasRole();
    if (!hasRole) return _StartupResult.needsRole;

    if (kIsWeb) return _StartupResult.ready;
    try {
      await scope.notifications.init();
      final foreground = await scope.permissions.hasForegroundLocation();
      final background = await scope.permissions.hasBackgroundLocation();

      if (foreground && background) {
        final prefs = await SharedPreferences.getInstance();
        final enabled = prefs.getBool('monitoring_enabled') ?? false;
        final serviceOn = await scope.location.isLocationServiceEnabled();
        if (enabled && serviceOn) {
          if (!scope.proximity.isRunning) {
            await scope.proximity.start();
          }
          final mosques = await scope.mosqueRepository.watchAll().first;
          await NativeProximityBridge.startNativeService(mosques);
        }
        return _StartupResult.ready;
      }
      return _StartupResult.needsPermissions;
    } catch (_) {
      return _StartupResult.ready;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupResult>(
      future: _readyFuture!,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: _emerald),
            ),
          );
        }
        return switch (snapshot.data!) {
          _StartupResult.needsRole => const RoleSelectionPage(),
          _StartupResult.needsPermissions => const PermissionOnboardingPage(),
          _StartupResult.ready => const HomePage(),
        };
      },
    );
  }
}

enum _StartupResult { needsRole, needsPermissions, ready }
