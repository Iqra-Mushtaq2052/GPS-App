import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../background/proximity_engine.dart';

class DiagnosticsPage extends StatelessWidget {
  final ScrollController? scrollController;

  const DiagnosticsPage({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scope = AppScope.of(context);
    
    Widget content = StreamBuilder<ProximitySnapshot>(
      stream: scope.proximity.snapshots,
      initialData: scope.proximity.currentSnapshot,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const ProximitySnapshot();
        final position = data.position;

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            if (scrollController != null) ...[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Center(
                child: Text('Live Diagnostics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
            ],
            if (!scope.proximity.isRunning)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  leading: Icon(Icons.pause_circle_outline, color: theme.colorScheme.secondary),
                  title: Text('Monitoring is off', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Turn ON the "Mosque Monitoring" switch on the home screen, '
                    'otherwise no live data will appear here.',
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            _GlassCard(
              borderColor: theme.colorScheme.primary,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.satellite_alt, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('GPS Fix', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Divider(color: theme.dividerColor, height: 24),
                    _Row('Provider', data.providerLabel),
                    if (position == null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.secondary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Waiting for GPS fix — ${data.secondsWithoutFix} seconds',
                              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Without internet, the first fix can take 1-3 minutes '
                        '(sometimes 10+ minutes) as the phone must read '
                        'satellite data directly from the sky. Stand under '
                        'the open sky — it will never get a fix indoors or '
                        'under a roof.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ] else ...[
                      _Row('Latitude', position.latitude.toStringAsFixed(6)),
                      _Row('Longitude', position.longitude.toStringAsFixed(6)),
                      _Row('Accuracy', '±${position.accuracy.toStringAsFixed(1)} m'),
                      _Row(
                        'Fix accepted?',
                        data.accuracyAccepted ? 'YES' : 'NO',
                        valueColor: data.accuracyAccepted ? theme.colorScheme.primary : Colors.redAccent,
                      ),
                      if (data.lastUpdate != null)
                        _Row('Last update', _fmt(data.lastUpdate!)),
                    ],
                    if (data.rejectionReason != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data.rejectionReason!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (data.lastEvent != null)
              _GlassCard(
                borderColor: theme.colorScheme.secondary,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bolt, color: theme.colorScheme.secondary),
                  ),
                  title: const Text('Last Event', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data.lastEvent!, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.map, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Mosque Distances', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Raw = Raw GPS distance (this jumps around).\n'
              'Smoothed = Median of 5 readings, decisions are based on this.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (data.readings.isEmpty)
              const _GlassCard(
                borderColor: Colors.grey,
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.grey),
                  title: Text('No enabled mosque, or fix not yet received.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ...data.readings.map((reading) {
                final paused = scope.proximity.isEnforcementPaused(reading.mosqueId);
                final isInside = reading.state == ZoneState.inside;
                final statusColor = isInside ? theme.colorScheme.primary : Colors.grey;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GlassCard(
                    borderColor: statusColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isInside ? Icons.location_on : Icons.location_off,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    reading.mosqueName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (isInside)
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    side: BorderSide(color: paused ? theme.colorScheme.secondary : theme.colorScheme.primary),
                                    foregroundColor: paused ? theme.colorScheme.secondary : theme.colorScheme.primary,
                                  ),
                                  onPressed: () => paused
                                      ? scope.proximity.resumeEnforcement(reading.mosqueId)
                                      : scope.proximity.pauseEnforcement(reading.mosqueId),
                                  child: Text(paused ? 'Resume' : 'Pause'),
                                ),
                            ],
                          ),
                          Divider(color: theme.dividerColor, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Raw Dist:', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                              Text('${reading.rawDistanceMeters.toStringAsFixed(1)} m'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Smoothed Dist:', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                              Text(
                                '${reading.smoothedDistanceMeters.toStringAsFixed(1)} m (radius ${reading.radiusMeters} m)',
                                style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('State:', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _stateLabel(reading.state),
                                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                reading.isConclusive ? Icons.check_circle : Icons.help_outline,
                                size: 14,
                                color: reading.isConclusive ? theme.colorScheme.primary : theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                reading.isConclusive
                                    ? 'Verdict: Conclusive (immediate action)'
                                    : 'Verdict: Uncertain (needs confirmation)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: reading.isConclusive ? theme.colorScheme.primary : theme.colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                          if (reading.pendingState != ZoneState.unknown) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Confirming: ${_stateLabel(reading.pendingState)} (~20 sec continuous)',
                              style: TextStyle(color: theme.colorScheme.secondary, fontSize: 12),
                            ),
                          ],
                          if (isInside) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (paused ? theme.colorScheme.secondary : theme.colorScheme.primary).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: (paused ? theme.colorScheme.secondary : theme.colorScheme.primary).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    paused ? Icons.notifications_paused : Icons.volume_off,
                                    size: 16,
                                    color: paused ? theme.colorScheme.secondary : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      paused
                                          ? 'Silent-lock: PAUSED for this visit'
                                          : 'Silent-lock: ON — will re-silence if unmuted',
                                      style: TextStyle(
                                        color: paused ? theme.colorScheme.secondary : theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );

    if (scrollController == null) {
      return Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [const Color(0xFF059669), Colors.transparent]
                    : [const Color(0xFF059669).withValues(alpha: 0.2), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          title: const Text('Live Diagnostics'),
        ),
        body: Container(
          decoration: isDark ? const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5,
              colors: [Color(0xFF161B22), Color(0xFF0D1117)],
            ),
          ) : null,
          child: content,
        ),
      );
    }
    
    return content;
  }

  static String _stateLabel(ZoneState state) => switch (state) {
        ZoneState.inside => 'INSIDE',
        ZoneState.outside => 'OUTSIDE',
        ZoneState.unknown => 'Unknown',
      };

  static String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _GlassCard({required this.child, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface.withValues(alpha: 0.7) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
