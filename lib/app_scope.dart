import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'background/proximity_engine.dart';
import 'core/discovery/mosque_discovery_service.dart';
import 'core/location/location_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/permissions/permission_service.dart';
import 'core/prayer/prayer_time_service.dart';
import 'core/ringer/ringer_change_watcher.dart';
import 'core/ringer/ringer_service.dart';
import 'core/role/role_service.dart';
import 'core/supabase/supabase_config.dart';
import 'core/supabase/supabase_service.dart';
import 'data/db/app_database.dart';
import 'data/repositories/mosque_repository.dart';

/// Holds every service singleton the app needs and makes them available to
/// the widget tree, avoiding a dependency on a separate state-management
/// package for what is otherwise a small set of plain service objects.
class AppScope extends InheritedWidget {
  AppScope({super.key, required super.child, AppDatabase? database})
      : database = database ?? AppDatabase(),
        location = LocationService(),
        prayerTimes = PrayerTimeService(),
        ringer = RingerService(),
        notifications = NotificationService(),
        permissions = PermissionService(),
        roleService = RoleService(),
        discovery = MosqueDiscoveryService() {
    mosqueRepository = MosqueRepository(this.database.mosqueDao);
    supabaseService = SupabaseService(roleService);
    proximity = ProximityEngine(
      mosqueRepository: mosqueRepository,
      ringer: ringer,
      notifications: notifications,
      prayerTimes: prayerTimes,
      ringerChanges: RingerChangeWatcher(),
    );

    // Route the "pause enforcement for this visit" notification button to
    // the engine — wired here since NotificationService must not know about
    // ProximityEngine (it is a generic alert sender used by other flows too).
    notifications.actionTaps.listen((action) {
      if (action.actionId != pauseEnforcementActionId) return;
      final mosqueId = int.tryParse(action.payload);
      if (mosqueId != null) proximity.pauseEnforcement(mosqueId);
    });
  }

  final AppDatabase database;
  late final MosqueRepository mosqueRepository;
  late final ProximityEngine proximity;
  late final SupabaseService supabaseService;
  final LocationService location;
  final PrayerTimeService prayerTimes;
  final RingerService ringer;
  final NotificationService notifications;
  final PermissionService permissions;
  final RoleService roleService;
  final MosqueDiscoveryService discovery;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

/// Initialize Supabase — called once in main() before runApp.
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    publishableKey: SupabaseConfig.anonKey,
  );
}
