import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../background/proximity_engine.dart';

/// Live view of exactly what the proximity engine sees: the raw GPS fix,
/// whether it was precise enough to trust, the raw vs smoothed distance to
/// every saved masjid, and why a reading was discarded. Without this the
/// only way to debug a wrong enter/exit was to guess from the outside.
class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Live Diagnostics')),
      body: StreamBuilder<ProximitySnapshot>(
        stream: scope.proximity.snapshots,
        initialData: scope.proximity.currentSnapshot,
        builder: (context, snapshot) {
          final data = snapshot.data ?? const ProximitySnapshot();
          final position = data.position;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!scope.proximity.isRunning)
                const Card(
                  color: Color(0xFFFFF3E0),
                  child: ListTile(
                    leading: Icon(Icons.pause_circle_outline, color: Colors.orange),
                    title: Text('Monitoring band hai'),
                    subtitle: Text(
                      'Home screen par "Masjid Monitoring" switch ON karein, '
                      'warna yahan koi live data nahi aayega.',
                    ),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GPS Fix',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _Row('Provider', data.providerLabel),
                      if (position == null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'GPS fix ka intezar — ${data.secondsWithoutFix} second',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Bina internet ke pehla fix asal mein 1-3 minute le '
                          'sakta hai (kabhi 10+ minute), kyunki phone ko '
                          'satellite data seedha aasman se parhna parta hai. '
                          'Khule aasman ke neeche khare hon — chhat ke neeche '
                          'ya andar kabhi nahi milega.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ] else ...[
                        _Row('Latitude', position.latitude.toStringAsFixed(6)),
                        _Row('Longitude', position.longitude.toStringAsFixed(6)),
                        _Row('Accuracy', '±${position.accuracy.toStringAsFixed(1)} m'),
                        _Row(
                          'Fix qabool hua?',
                          data.accuracyAccepted ? 'HAAN' : 'NAHI',
                        ),
                        if (data.lastUpdate != null)
                          _Row('Last update', _fmt(data.lastUpdate!)),
                      ],
                      if (data.rejectionReason != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          data.rejectionReason!,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (data.lastEvent != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.bolt),
                    title: const Text('Aakhri event'),
                    subtitle: Text(data.lastEvent!),
                  ),
                ),
              const SizedBox(height: 12),
              Text('Masjid Distances',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                'Raw = GPS ka kachcha number (ye uchalta hai). '
                'Smoothed = 5 readings ka median, faisla isi par hota hai.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              if (data.readings.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('Koi enabled masjid nahi, ya abhi fix nahi mila.'),
                  ),
                )
              else
                ...data.readings.map((reading) {
                  final paused = scope.proximity.isEnforcementPaused(reading.mosqueId);
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        reading.state == ZoneState.inside
                            ? Icons.location_on
                            : Icons.location_off,
                        color: reading.state == ZoneState.inside
                            ? Colors.green
                            : Colors.grey,
                      ),
                      title: Text(reading.mosqueName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Raw: ${reading.rawDistanceMeters.toStringAsFixed(1)} m'),
                          Text(
                            'Smoothed: ${reading.smoothedDistanceMeters.toStringAsFixed(1)} m '
                            '(radius ${reading.radiusMeters} m)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('State: ${_stateLabel(reading.state)}'),
                          Text(
                            reading.isConclusive
                                ? 'Faisla: pakka (foran amal)'
                                : 'Faisla: mashkook (confirm karna parega)',
                            style: TextStyle(
                              color: reading.isConclusive
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          if (reading.pendingState != ZoneState.unknown)
                            Text(
                              'Confirm ho raha hai: ${_stateLabel(reading.pendingState)} '
                              '(~20 sec lagatar)',
                              style: const TextStyle(color: Colors.orange),
                            ),
                          if (reading.state == ZoneState.inside) ...[
                            const SizedBox(height: 4),
                            Text(
                              paused
                                  ? 'Silent-lock: Is visit ke liye ROKA hua hai'
                                  : 'Silent-lock: ON — unmute karte hi wapas silent ho jayega',
                              style: TextStyle(
                                color: paused ? Colors.orange : Colors.teal,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: reading.state == ZoneState.inside
                          ? TextButton(
                              onPressed: () => paused
                                  ? scope.proximity.resumeEnforcement(reading.mosqueId)
                                  : scope.proximity.pauseEnforcement(reading.mosqueId),
                              child: Text(paused ? 'Resume' : 'Rokein'),
                            )
                          : null,
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  static String _stateLabel(ZoneState state) => switch (state) {
        ZoneState.inside => 'ANDAR',
        ZoneState.outside => 'BAHAR',
        ZoneState.unknown => 'abhi maloom nahi',
      };

  static String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
