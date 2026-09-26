import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_mode_advanced/utils/ringer_mode_statuses.dart';

import '../core/notifications/notification_service.dart';
import '../core/ringer/ringer_change_watcher.dart';
import '../core/ringer/ringer_service.dart';
import '../data/db/app_database.dart';
import '../data/repositories/mosque_repository.dart';

/// While true, the prayer-time gate is skipped so the boundary logic can be
/// tested on its own. Turn off from Settings once the radius behaves.
const prefsIgnorePrayerTimeKey = 'testing_mode_ignore_prayer_time';

/// A GPS fix whose own reported error exceeds this is discarded rather than
/// used for a decision. Consumer GPS near buildings commonly reports 10-50m
/// error, and acting on a low-confidence fix is what produced "you are
/// outside" while standing inside.
const _maxAcceptableAccuracyMeters = 30.0;

/// Readings kept for the median filter. A median (not an average) is used
/// because it discards one-off spikes outright — the "suddenly 85 then 70"
/// jumps seen in the field — instead of averaging them in.
const _smoothingWindow = 5;

/// A fix implying movement faster than this since the previous fix is a GPS
/// teleport, not real motion, and is dropped.
const _maxPlausibleSpeedMps = 12.0; // ~43 km/h; well above walking speed.

/// Exit is only declared past radius + this buffer (asymmetric hysteresis),
/// so a reading wobbling across the boundary cannot flip state repeatedly.
const _exitBufferMeters = 15.0;

/// Required only when the reading is *ambiguous*. An unambiguous reading
/// (see [_Confidence]) acts immediately, which is what makes entry feel
/// instant instead of always waiting out a timer.
const _ambiguousDwell = Duration(seconds: 20);

const _pollInterval = Duration(seconds: 4);

/// If no fix at all arrives in this long, switch to the other location
/// provider. Neither provider is reliable on every device: the fused
/// provider needs Google Play Services and leans on network positioning
/// (so it can starve with no data connection), while forcing the legacy
/// LocationManager is reported to return nothing on some devices that do
/// have Play Services. Trying both is the only robust option.
const _providerFallbackAfter = Duration(seconds: 45);

enum ZoneState { inside, outside, unknown }

/// Whether a reading is decisive on its own. A fix is only treated as
/// conclusive when the boundary lies outside the fix's own error circle —
/// e.g. 12m away with ±8m accuracy is definitely inside a 40m radius, while
/// 38m away with ±25m accuracy proves nothing.
enum _Confidence { clear, ambiguous }

class ProximityReading {
  const ProximityReading({
    required this.mosqueId,
    required this.mosqueName,
    required this.rawDistanceMeters,
    required this.smoothedDistanceMeters,
    required this.radiusMeters,
    required this.state,
    required this.pendingState,
    required this.isConclusive,
  });

  final int mosqueId;
  final String mosqueName;
  final double rawDistanceMeters;
  final double smoothedDistanceMeters;
  final int radiusMeters;
  final ZoneState state;
  final ZoneState pendingState;
  final bool isConclusive;
}

class ProximitySnapshot {
  const ProximitySnapshot({
    this.position,
    this.accuracyAccepted = false,
    this.rejectionReason,
    this.readings = const [],
    this.lastUpdate,
    this.lastEvent,
    this.providerLabel = '—',
    this.secondsWithoutFix = 0,
    this.hasEverFixed = false,
  });

  final Position? position;
  final bool accuracyAccepted;

  /// Which Android location provider is currently in use.
  final String providerLabel;

  /// How long we have been waiting with no fix at all. Offline the first
  /// fix legitimately takes minutes, so "nothing yet" must be
  /// distinguishable from "broken".
  final int secondsWithoutFix;
  final bool hasEverFixed;

  /// Why a fix was thrown away, shown in diagnostics so a "nothing is
  /// happening" moment is explainable rather than mysterious.
  final String? rejectionReason;
  final List<ProximityReading> readings;
  final DateTime? lastUpdate;
  final String? lastEvent;
}

/// Watches GPS directly and decides enter/exit itself.
///
/// Android's native Geofencing API was removed from this app because it
/// depends on the network location provider (so it needs a data
/// connection) and is documented as unreliable below ~100m, while this app
/// must run offline at 20-60m radii.
class ProximityEngine {
  // Initializing formals can't be used here: named parameters may not start
  // with an underscore, so private fields must be assigned in the body.
  // ignore_for_file: prefer_initializing_formals
  ProximityEngine({
    required MosqueRepository mosqueRepository,
    required RingerService ringer,
    required NotificationService notifications,
    required RingerChangeWatcher ringerChanges,
  })  : _mosqueRepository = mosqueRepository,
        _ringer = ringer,
        _notifications = notifications,
        _ringerChanges = ringerChanges;

  final MosqueRepository _mosqueRepository;
  final RingerService _ringer;
  final NotificationService _notifications;
  final RingerChangeWatcher _ringerChanges;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<void>? _ringerChangeSub;
  List<Mosque> _mosques = const [];

  final _zoneStates = <int, ZoneState>{};
  final _pendingStates = <int, ZoneState>{};
  final _pendingSince = <int, DateTime>{};
  final _distanceHistory = <int, List<double>>{};

  /// Mosques where the user tapped "pause enforcement for this visit" —
  /// re-silencing is skipped for these until the next entry (see
  /// [_handleTransition], which clears an id on every transition).
  final _enforcementPaused = <int>{};

  /// Prevents concurrent [_onRingerChanged] runs from interfering with
  /// each other — the second broadcast (from our own setSoundMode call)
  /// must not start a new re-silence cycle.
  bool _ringerChangeInProgress = false;

  bool isEnforcementPaused(int mosqueId) => _enforcementPaused.contains(mosqueId);

  Position? _lastAcceptedPosition;

  /// Start with the legacy LocationManager: it talks to the GPS chip
  /// directly, which is what makes a fix possible with no data connection.
  bool _useLocationManager = true;
  bool _hasEverFixed = false;
  DateTime? _streamStartedAt;
  Timer? _watchdog;

  final _snapshotController = StreamController<ProximitySnapshot>.broadcast();
  ProximitySnapshot _snapshot = const ProximitySnapshot();

  Stream<ProximitySnapshot> get snapshots => _snapshotController.stream;
  ProximitySnapshot get currentSnapshot => _snapshot;
  bool get isRunning => _positionSub != null;

  static String _stateKey(int mosqueId) => 'zone_state_$mosqueId';

  Future<void> start() async {
    if (_positionSub != null) return;

    _mosques = await _mosqueRepository.watchAll().first;
    await _loadPersistedStates();
    await _enforceRingerIfNeeded();
    await _startStream();

    _ringerChangeSub ??= _ringerChanges.changes.listen((_) => _onRingerChanged());

    _watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      final startedAt = _streamStartedAt;
      if (startedAt == null) return;
      final waiting = DateTime.now().difference(startedAt);

      if (!_hasEverFixed && waiting >= _providerFallbackAfter) {
        // Still nothing from this provider — try the other one.
        _useLocationManager = !_useLocationManager;
        _emit(_snapshot,
            event: 'Koi fix nahi mila — ab ${_providerLabel()} try kar rahe hain');
        _startStream();
        return;
      }
      // Keep the "waiting" counter live in the UI.
      if (!_hasEverFixed) _emit(_snapshot);
    });
  }

  String _providerLabel() =>
      _useLocationManager ? 'GPS chip (offline-capable)' : 'Google Play Services';

  Future<void> _startStream() async {
    await _positionSub?.cancel();

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      intervalDuration: _pollInterval,
      // The whole point of this app is working with no internet, so prefer
      // the provider that reads the GPS chip directly.
      forceLocationManager: _useLocationManager,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: '🕌 Mosque Auto-Silent Active',
        notificationText: 'Monitoring nearby mosques in background (100% Active)',
        notificationChannelName: 'Masjid Proximity Monitoring',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );

    _streamStartedAt = DateTime.now();
    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (Object error) {
      _emit(_snapshot, event: 'Location error: $error');
    });
  }

  /// Restores the inside/outside state from disk. Without this, every cold
  /// start began at [ZoneState.unknown] and the first "outside" reading
  /// looked like a fresh exit — which is why rebooting the phone produced a
  /// bogus "ringer restored" notification.
  Future<void> _loadPersistedStates() async {
    final prefs = await SharedPreferences.getInstance();
    for (final mosque in _mosques) {
      final stored = prefs.getString(_stateKey(mosque.id));
      if (stored != null) {
        _zoneStates[mosque.id] = ZoneState.values.firstWhere(
          (s) => s.name == stored,
          orElse: () => ZoneState.unknown,
        );
      }
    }
  }

  Future<void> _persistState(int mosqueId, ZoneState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey(mosqueId), state.name);
  }

  Future<void> stop() async {
    _watchdog?.cancel();
    _watchdog = null;
    await _positionSub?.cancel();
    _positionSub = null;
    await _ringerChangeSub?.cancel();
    _ringerChangeSub = null;
    _pendingStates.clear();
    _pendingSince.clear();
    _distanceHistory.clear();
    _enforcementPaused.clear();
    _ringerChangeInProgress = false;
    _lastAcceptedPosition = null;
    _streamStartedAt = null;
    _hasEverFixed = false;
    _emit(const ProximitySnapshot(), event: 'Monitoring stopped');
  }

  /// Pauses re-silencing for [mosqueId] until the next entry, and restores
  /// the ringer immediately if this app is the one currently holding it
  /// silent — the explicit escape hatch for e.g. an urgent call, so
  /// enforcement never traps the user with no way out.
  Future<void> pauseEnforcement(int mosqueId) async {
    _enforcementPaused.add(mosqueId);
    if (await _ringer.silencedByApp()) {
      await _ringer.restorePreviousMode();
    }
    final name = _mosqueNameById(mosqueId) ?? 'Masjid';
    _emit(_snapshot, event: '$name — is visit ke liye enforcement rok diya gaya');
  }

  /// Removes a visit-scoped pause and, if still inside, re-silences right
  /// away instead of waiting for the next ringer-change broadcast. The
  /// in-app counterpart to the notification's pause button, for when the
  /// user has the app open on the Diagnostics page.
  Future<void> resumeEnforcement(int mosqueId) async {
    _enforcementPaused.remove(mosqueId);
    if (_zoneStates[mosqueId] != ZoneState.inside) return;

    final result = await _ringer.silenceForPrayer();
    final name = _mosqueNameById(mosqueId) ?? 'Masjid';
    if (result == RingerActionResult.changed) {
      await _notifications.show(
        title: 'Phone silent kar diya',
        body: '$name ke andar hain — enforcement dobara ON kar diya gaya.',
      );
    }
    _emit(_snapshot, event: '$name — enforcement dobara ON kar diya gaya');
  }

  /// Reacts to a live ringer/DND broadcast: if the user just un-silenced
  /// the phone while still inside a masjid we silenced it for (and
  /// enforcement isn't paused for that visit), silence it again — this is
  /// what makes the phone "stay" silent instead of only being silenced once
  /// on entry.
  ///
  /// A re-entrancy guard prevents the broadcast fired by our own
  /// [silenceForPrayer] call from triggering a second cycle.  An 800ms
  /// delay lets Android's volume-slider UI release control of the ringer
  /// before we attempt to change it, and a single retry handles the rare
  /// case where Android still overrides the first attempt.
  Future<void> _onRingerChanged() async {
    // ── Guard: skip if we are already handling a ringer change ──
    if (_ringerChangeInProgress) return;
    _ringerChangeInProgress = true;
    try {
      await _onRingerChangedCore();
    } finally {
      _ringerChangeInProgress = false;
    }
  }

  Future<void> _onRingerChangedCore() async {
    // Small delay so Android's volume-slider UI releases the ringer first.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await _enforceRingerIfNeeded();
  }

  String? _mosqueNameById(int mosqueId) {
    for (final m in _mosques) {
      if (m.id == mosqueId) return m.name;
    }
    return null;
  }

  Future<void> refreshMosques() async {
    _mosques = await _mosqueRepository.watchAll().first;
    await _loadPersistedStates();
  }

  Future<void> _onPosition(Position position) async {
    final now = DateTime.now();
    // A fix arrived, so stop hunting for a working provider.
    _hasEverFixed = true;

    if (position.accuracy > _maxAcceptableAccuracyMeters) {
      _emit(ProximitySnapshot(
        position: position,
        accuracyAccepted: false,
        rejectionReason:
            'Accuracy ±${position.accuracy.toStringAsFixed(0)}m — '
            '${_maxAcceptableAccuracyMeters.toStringAsFixed(0)}m se kharab, ignore kiya',
        readings: _snapshot.readings,
        lastUpdate: now,
        lastEvent: _snapshot.lastEvent,
      ));
      return;
    }

    // Reject GPS "teleports": a jump that would require implausible speed.
    final previous = _lastAcceptedPosition;
    if (previous != null) {
      final jump = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
      final seconds = position.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
      if (seconds > 0 && jump / seconds > _maxPlausibleSpeedMps) {
        _emit(ProximitySnapshot(
          position: position,
          accuracyAccepted: false,
          rejectionReason:
              'GPS jump ${jump.toStringAsFixed(0)}m in ${seconds.toStringAsFixed(1)}s '
              '— na-mumkin raftaar, ignore kiya',
          readings: _snapshot.readings,
          lastUpdate: now,
          lastEvent: _snapshot.lastEvent,
        ));
        return;
      }
    }
    _lastAcceptedPosition = position;

    final readings = <ProximityReading>[];

    for (final mosque in _mosques.where((m) => m.isEnabled)) {
      final rawDistance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        mosque.latitude,
        mosque.longitude,
      );

      final smoothed = _smoothDistance(mosque.id, rawDistance);
      final current = _zoneStates[mosque.id] ?? ZoneState.unknown;

      final (observed, confidence) = _classify(
        smoothedDistance: smoothed,
        accuracy: position.accuracy,
        radius: mosque.radiusMeters.toDouble(),
        current: current,
      );

      var pending = _pendingStates[mosque.id] ?? ZoneState.unknown;

      if (observed != current && observed != ZoneState.unknown) {
        if (confidence == _Confidence.clear) {
          // Unambiguous: act now, no waiting.
          _zoneStates[mosque.id] = observed;
          _pendingStates[mosque.id] = ZoneState.unknown;
          pending = ZoneState.unknown;
          await _persistState(mosque.id, observed);
          await _handleTransition(mosque, observed, from: current);
        } else if (pending != observed) {
          pending = observed;
          _pendingStates[mosque.id] = observed;
          _pendingSince[mosque.id] = now;
        } else {
          final since = _pendingSince[mosque.id] ?? now;
          if (now.difference(since) >= _ambiguousDwell) {
            _zoneStates[mosque.id] = observed;
            _pendingStates[mosque.id] = ZoneState.unknown;
            pending = ZoneState.unknown;
            await _persistState(mosque.id, observed);
            await _handleTransition(mosque, observed, from: current);
          }
        }
      } else if (observed == current) {
        pending = ZoneState.unknown;
        _pendingStates[mosque.id] = ZoneState.unknown;
      }

      readings.add(ProximityReading(
        mosqueId: mosque.id,
        mosqueName: mosque.name,
        rawDistanceMeters: rawDistance,
        smoothedDistanceMeters: smoothed,
        radiusMeters: mosque.radiusMeters,
        state: _zoneStates[mosque.id] ?? ZoneState.unknown,
        pendingState: pending,
        isConclusive: confidence == _Confidence.clear,
      ));
    }

    _emit(ProximitySnapshot(
      position: position,
      accuracyAccepted: true,
      readings: readings,
      lastUpdate: now,
      lastEvent: _snapshot.lastEvent,
    ));

    // ── Polling-based ringer enforcement ──
    // Some devices (Vivo, Oppo, Xiaomi) don't reliably deliver the
    // RINGER_MODE_CHANGED broadcast, so the event-based _onRingerChanged
    // never fires.  This check runs on every GPS fix (~4 s) and
    // re-silences if the user somehow un-muted while still inside.
    await _enforceRingerIfNeeded();
  }

  /// Re-silences the phone if the user un-muted while inside a mosque.
  /// Called from two places:
  /// 1. [_onRingerChanged] — fast path, reacts within ~1 s via broadcast.
  /// 2. [_onPosition]      — slow path, polls every ~4 s as a fallback.
  Future<void> _enforceRingerIfNeeded() async {
    Mosque? active;
    for (final m in _mosques) {
      if (_zoneStates[m.id] == ZoneState.inside &&
          !_enforcementPaused.contains(m.id)) {
        active = m;
        break;
      }
    }
    if (active == null) return;

    // Only work when Location / GPS is turned ON
    if (!await Geolocator.isLocationServiceEnabled()) {
      return;
    }

    final mode = await _ringer.currentMode();
    // Already vibrate or silent — no enforcement needed
    if (mode == RingerModeStatus.vibrate || mode == RingerModeStatus.silent) return;

    // Inside mosque and phone is on normal mode — force vibrate
    final result = await _ringer.silenceForPrayer();
    if (result == RingerActionResult.changed) {
      await _notifications.show(
        title: '📳 Phone Vibrate — ${active.name}',
        body: '${active.name} ke andar hain — phone vibrate mode par laga diya gaya.',
        actions: [
          const AndroidNotificationAction(
            pauseEnforcementActionId,
            'Is visit ke liye rok dein',
          ),
        ],
        payload: '${active.id}',
      );
      _emit(_snapshot,
          event: '${active.name} — masjid ke andar, vibrate mode active kiya');
    }
  }

  /// Median of the last [_smoothingWindow] readings. Chosen over a mean
  /// because a single wild sample cannot drag a median.
  double _smoothDistance(int mosqueId, double rawDistance) {
    final history = _distanceHistory.putIfAbsent(mosqueId, () => <double>[]);
    history.add(rawDistance);
    if (history.length > _smoothingWindow) history.removeAt(0);

    final sorted = [...history]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Decides inside/outside and how much to trust that call.
  ///
  /// The fix's own accuracy is treated as an error bar: the reading is only
  /// conclusive when the entire error bar sits on one side of the boundary.
  (ZoneState, _Confidence) _classify({
    required double smoothedDistance,
    required double accuracy,
    required double radius,
    required ZoneState current,
  }) {
    final margin = math.max(accuracy, 5.0);

    if (smoothedDistance + margin < radius) {
      return (ZoneState.inside, _Confidence.clear);
    }
    if (smoothedDistance - margin > radius + _exitBufferMeters) {
      return (ZoneState.outside, _Confidence.clear);
    }
    if (smoothedDistance <= radius) {
      return (ZoneState.inside, _Confidence.ambiguous);
    }
    if (smoothedDistance > radius + _exitBufferMeters) {
      return (ZoneState.outside, _Confidence.ambiguous);
    }
    return (current, _Confidence.ambiguous);
  }

  Future<void> _handleTransition(
    Mosque mosque,
    ZoneState state, {
    required ZoneState from,
  }) async {
    _enforcementPaused.remove(mosque.id);

    if (state == ZoneState.inside) {
      // Entering mosque — set phone to vibrate
      final result = await _ringer.silenceForPrayer();
      switch (result) {
        case RingerActionResult.changed:
          await _notifications.show(
            title: '📳 Phone Vibrate — ${mosque.name}',
            body: 'Masjid ke range me hain. Phone vibrate mode par laga diya gaya.',
            actions: [
              const AndroidNotificationAction(
                pauseEnforcementActionId,
                'Is visit ke liye rok dein',
              ),
            ],
            payload: '${mosque.id}',
          );
          _emit(_snapshot, event: '${mosque.name} — andar, vibrate kar diya');
        case RingerActionResult.alreadyInDesiredState:
          _emit(_snapshot, event: '${mosque.name} — andar, pehle se vibrate par tha');
        case RingerActionResult.noPermission:
          _emit(_snapshot, event: '${mosque.name} — andar, permission nahi hai');
        case RingerActionResult.notOurs:
          _emit(_snapshot, event: '${mosque.name} — andar, koi tabdeeli nahi');
      }
      return;
    }

    // Exiting mosque — restore ringer to normal
    if (from != ZoneState.inside) {
      _emit(_snapshot, event: '${mosque.name} — bahar (initial state)');
      return;
    }

    final result = await _ringer.restorePreviousMode();
    switch (result) {
      case RingerActionResult.changed:
        await _notifications.show(
          title: '🔔 Ringer Normal — ${mosque.name}',
          body: 'Masjid se bahar aa gaye. Ringer wapas normal kar diya gaya.',
        );
        _emit(_snapshot, event: '${mosque.name} — bahar, ringer restore kiya');
      case RingerActionResult.alreadyInDesiredState:
      case RingerActionResult.notOurs:
        _emit(_snapshot, event: '${mosque.name} — bahar, ringer pehle se normal tha');
      case RingerActionResult.noPermission:
        _emit(_snapshot, event: '${mosque.name} — bahar, permission nahi hai');
    }
  }

  /// Rebuilds the snapshot with the live provider/waiting fields filled in,
  /// so every call site does not have to repeat them.
  void _emit(ProximitySnapshot snapshot, {String? event}) {
    final startedAt = _streamStartedAt;
    _snapshot = ProximitySnapshot(
      position: snapshot.position,
      accuracyAccepted: snapshot.accuracyAccepted,
      rejectionReason: snapshot.rejectionReason,
      readings: snapshot.readings,
      lastUpdate: snapshot.lastUpdate,
      lastEvent: event == null
          ? snapshot.lastEvent
          : '${_formatTime(DateTime.now())} — $event',
      providerLabel: _providerLabel(),
      secondsWithoutFix: (_hasEverFixed || startedAt == null)
          ? 0
          : DateTime.now().difference(startedAt).inSeconds,
      hasEverFixed: _hasEverFixed,
    );
    if (!_snapshotController.isClosed) _snapshotController.add(_snapshot);
  }

  static String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  void dispose() {
    _watchdog?.cancel();
    _positionSub?.cancel();
    _ringerChangeSub?.cancel();
    _snapshotController.close();
  }
}
