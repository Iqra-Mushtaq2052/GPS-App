import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Action id used on the "pause enforcement for this visit" button attached
/// to silence notifications. The payload carries the mosque id so the
/// listener knows which visit to pause.
const pauseEnforcementActionId = 'pause_enforcement';

/// Wraps flutter_local_notifications for the one-off alert shown when a
/// masjid geofence is entered/exited ("phone silenced" / "silent mode
/// restored"). The persistent foreground-service notification required by
/// geofence_foreground_service is managed by that plugin itself.
class NotificationService {
  static const _channelId = 'masjid_proximity_alerts';
  static const _channelName = 'Masjid Proximity Alerts';

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Fires whenever the user taps a notification action button (currently
  /// only "pause enforcement"), carrying the action id and payload
  /// (mosque id) together.
  Stream<NotificationAction> get actionTaps => _actionStreamController.stream;
  final _actionStreamController = StreamController<NotificationAction>.broadcast();

  Future<void> init() async {
    if (kIsWeb) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onResponse,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void _onResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    if (actionId != null && payload != null) {
      _actionStreamController.add(NotificationAction(actionId, payload));
    }
  }

  Future<void> show({
    required String title,
    required String body,
    List<AndroidNotificationAction> actions = const [],
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Alerts when entering/exiting a saved masjid area',
      importance: Importance.high,
      priority: Priority.high,
      actions: actions,
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  void dispose() {
    unawaited(_actionStreamController.close());
  }
}

class NotificationAction {
  const NotificationAction(this.actionId, this.payload);
  final String actionId;
  final String payload;
}
