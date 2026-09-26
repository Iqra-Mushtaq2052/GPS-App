import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../app.dart'; // for MainShell
import '../../app_scope.dart';
import '../../core/supabase/supabase_service.dart';
import '../../data/db/app_database.dart';
import 'mosque_detail_page.dart';

class MyMasajidPage extends StatefulWidget {
  const MyMasajidPage({super.key});

  @override
  State<MyMasajidPage> createState() => _MyMasajidPageState();
}

class _MyMasajidPageState extends State<MyMasajidPage> {
  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  MapEntry<String, DateTime>? _nextPrayer(CloudPrayerTimes? times) {
    if (times == null) return null;
    final todayMap = times.toTodayDateTimes();
    final now = DateTime.now();
    for (final entry in todayMap.entries) {
      if (entry.value.isAfter(now)) {
        return entry;
      }
    }
    return todayMap.entries.isNotEmpty ? todayMap.entries.first : null;
  }

  Future<void> _confirmRemove(BuildContext context, AppScope scope, Mosque mosque) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Mosque?'),
        content: Text('Are you sure you want to remove ${mosque.name} from your downloaded masajid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await scope.sync.removeDownloaded(mosque);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: scope.sync,
      builder: (context, _) {
        final isLive = scope.sync.isLive;
        final isImam = scope.auth.isSignedIn;
        final managedMosques = scope.sync.managedMosques;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('My Masajid'),
                const SizedBox(width: 8),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLive ? const Color(0xFF10B981) : Colors.grey,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => scope.sync.refresh(),
              ),
            ],
          ),
          body: StreamBuilder<List<Mosque>>(
            stream: scope.mosqueRepository.watchAll(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final mosques = snapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (isImam && managedMosques.isNotEmpty) ...[
                    Text(
                      'Managed Mosques (Imam)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...managedMosques.map((managed) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.5)),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.workspace_premium, color: theme.colorScheme.secondary, size: 32),
                          title: Text(managed.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: managed.address != null && managed.address!.isNotEmpty
                              ? Text(managed.address!)
                              : Text(managed.isImam ? 'Imam' : 'Committee Member'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // Use the local mosque if already downloaded, else pass as CloudMosque
                            final local = scope.sync.localFor(managed.id);
                            if (local != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => MosqueDetailPage(mosque: local)),
                              );
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => MosqueDetailPage(cloudMosque: managed)),
                              );
                            }
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Text(
                      'Downloaded Mosques',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (mosques.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(Icons.mosque, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text(
                              'No mosques downloaded yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: () => MainShell.jumpTo(context, 1), // 1 is Discover tab
                              icon: const Icon(Icons.explore),
                              label: const Text('Discover Nearby Mosques'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...mosques.map((mosque) {
                      final times = mosque.supabaseId != null ? scope.sync.timesFor(mosque.supabaseId!) : null;
                      final next = _nextPrayer(times);
                      
                      double? distanceMeters;
                      final pos = scope.proximity.currentSnapshot.position;
                      if (pos != null) {
                        distanceMeters = Geolocator.distanceBetween(
                          pos.latitude, pos.longitude,
                          mosque.latitude, mosque.longitude,
                        );
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => MosqueDetailPage(mosque: mosque)),
                          ),
                          onLongPress: () => _confirmRemove(context, scope, mosque),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            mosque.name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (distanceMeters != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.location_on, size: 12, color: theme.colorScheme.primary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${_formatDistance(distanceMeters)} away',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.colorScheme.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: mosque.isEnabled,
                                      onChanged: (val) async {
                                        await scope.mosqueRepository.update(mosque.copyWith(isEnabled: val));
                                        await scope.proximity.refreshMosques();
                                      },
                                      activeThumbColor: theme.colorScheme.primary,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _confirmRemove(context, scope, mosque),
                                    ),
                                  ],
                                ),
                                if (times != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF161B22) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time_filled, color: theme.colorScheme.secondary, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: next != null
                                            ? Text.rich(
                                                TextSpan(
                                                  children: [
                                                    const TextSpan(text: 'Next Jamaat: '),
                                                    TextSpan(
                                                      text: '${next.key} at ${_formatTime(next.value)}',
                                                      style: TextStyle(
                                                        color: theme.colorScheme.secondary,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                style: const TextStyle(fontSize: 14),
                                              )
                                            : const Text('Live times connected'),
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
          ),
        );
      },
    );
  }
}
