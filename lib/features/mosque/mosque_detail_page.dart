import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app_scope.dart';
import '../../core/supabase/supabase_service.dart';
import '../../data/db/app_database.dart';
import 'add_mosque_page.dart';
import 'committee_page.dart';
import 'imam_prayer_times_page.dart';

class MosqueDetailPage extends StatefulWidget {
  const MosqueDetailPage({
    super.key,
    this.mosque,
    this.cloudMosque,
  }) : assert(mosque != null || cloudMosque != null);

  final Mosque? mosque;
  final CloudMosque? cloudMosque;

  @override
  State<MosqueDetailPage> createState() => _MosqueDetailPageState();
}

class _MosqueDetailPageState extends State<MosqueDetailPage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      AppScope.of(context).sync.refresh();
    }
  }

  Future<void> _toggleVibrate(Mosque m, bool value) async {
    final scope = AppScope.of(context);
    await scope.mosqueRepository.update(m.copyWith(isEnabled: value));
    await scope.sync.onLocalMosquesChanged?.call();
  }

  Future<void> _remove(Mosque m) async {
    final scope = AppScope.of(context);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Mosque?'),
        content: Text('"${m.name}" will be removed. You will no longer receive live times or announcements.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await scope.sync.removeDownloaded(m);
    navigator.pop();
  }

  Future<void> _postAnnouncement(String cloudId) async {
    final posted = await showAnnouncementComposer(context, cloudMosqueId: cloudId);
    if (posted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement posted successfully.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final sync = scope.sync;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final cloudId = widget.mosque?.supabaseId ?? widget.cloudMosque?.id;
        final m = sync.localFor(cloudId) ?? widget.mosque;
        final cMosque = widget.cloudMosque;
        final name = m?.name ?? cMosque?.name ?? 'Mosque Details';
        final latitude = m?.latitude ?? cMosque?.latitude ?? 0.0;
        final longitude = m?.longitude ?? cMosque?.longitude ?? 0.0;
        final radiusMeters = m?.radiusMeters ?? cMosque?.radiusMeters ?? 40;
        
        final times = sync.timesFor(cloudId);
        final anns = cloudId == null ? const <CloudAnnouncement>[] : sync.announcementsFor([cloudId]);
        final managed = sync.managedFor(cloudId);

        final isDownloaded = m != null;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
                if (cloudId != null) ...[ const SizedBox(width: 8), _LiveDot(live: sync.isLive) ],
              ],
            ),
          ),
          floatingActionButton: (managed != null && cloudId != null)
              ? FloatingActionButton.extended(
                  onPressed: () => _postAnnouncement(cloudId),
                  icon: const Icon(Icons.campaign),
                  label: const Text('Post Announcement'),
                  backgroundColor: const Color(0xFF10B981),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: sync.refresh,
            color: const Color(0xFF10B981),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Hero header card ──
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: isDark ? const Color(0xFF161B22) : theme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.map, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            // Simplified distance presentation
                            const Text('Live distance tracking active', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (isDownloaded) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: m.isEnabled ? const Color(0xFF10B981) : Colors.amber,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  m.isEnabled ? 'INSIDE' : 'Monitoring Off', // Placeholder logic for status
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Spacer(),
                              const Text('Auto-vibrate'),
                              Switch(
                                value: m.isEnabled,
                                onChanged: (v) => _toggleVibrate(m, v),
                                activeThumbColor: const Color(0xFF10B981),
                              ),
                            ],
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () async {
                                if (cMosque != null) {
                                  await scope.sync.downloadMosque(cMosque as StoreMosque);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Mosque downloaded!')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.download),
                              label: const Text('Download Mosque'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Map section showing mosque location
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 160,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(latitude, longitude),
                        initialZoom: 16,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none, // static, non-interactive
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.gpsapp.gps_app',
                        ),
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: LatLng(latitude, longitude),
                              radius: radiusMeters.toDouble(),
                              useRadiusInMeter: true,
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderColor: const Color(0xFF10B981),
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(latitude, longitude),
                              width: 44,
                              height: 44,
                              child: const Icon(Icons.mosque, color: Color(0xFF10B981), size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Prayer Times section ──
                _PrayerTimesSection(
                  times: times,
                  latitude: latitude,
                  longitude: longitude,
                  canEdit: managed != null,
                  onEdit: () {
                    if (cloudId != null && m != null && managed != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ImamPrayerTimesPage(
                            mosqueId: m.id,
                            mosqueName: m.name,
                            shareCode: managed.shareCode,
                            cloudMosqueId: cloudId,
                          ),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),

                // ── Announcements section ──
                Row(
                  children: [
                    const Icon(Icons.campaign, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    const Text('Announcements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                if (anns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No announcements yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  )
                else
                  ...anns.map((a) => AnnouncementTile(
                        announcement: a,
                        canDelete: managed != null,
                      )),
                
                const SizedBox(height: 24),

                // ── Imam Dashboard section ──
                if (managed != null && cloudId != null) ...[
                  const Text('Imam Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    color: isDark ? const Color(0xFF161B22) : theme.cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        if (managed.isImam)
                          ListTile(
                            leading: const Icon(Icons.edit, color: Color(0xFFF59E0B)),
                            title: const Text('Edit Mosque Details'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMosquePage()));
                            },
                          ),
                        if (managed.isImam) const Divider(height: 1),
                        if (managed.isImam)
                          ListTile(
                            leading: const Icon(Icons.groups, color: Color(0xFF10B981)),
                            title: const Text('Manage Committee'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommitteePage(mosque: managed)));
                            },
                          ),
                        if (managed.isImam) const Divider(height: 1),
                        if (managed.isImam)
                          ListTile(
                            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                            title: const Text('Delete Mosque', style: TextStyle(color: Colors.redAccent)),
                            onTap: () {
                              // Dummy action for delete
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Actions section ──
                if (isDownloaded && managed == null)
                  OutlinedButton.icon(
                    onPressed: () => _remove(m),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Remove from My Masajid', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PrayerTimesSection extends StatelessWidget {
  const _PrayerTimesSection({
    required this.times,
    required this.latitude,
    required this.longitude,
    required this.canEdit,
    required this.onEdit,
  });

  final CloudPrayerTimes? times;
  final double latitude;
  final double longitude;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Fallback logic using scope prayerTimes could be implemented here
    // For now we just show API times or placeholders
    
    final t = times;
    final rows = t == null
        ? [
            const MapEntry('Fajr', '05:00'),
            const MapEntry('Zuhr', '13:00'),
            const MapEntry('Asr', '17:00'),
            const MapEntry('Maghrib', '18:30'),
            const MapEntry('Isha', '20:00'),
          ]
        : [
            MapEntry('Fajr', t.fajr),
            MapEntry('Zuhr', t.dhuhr),
            MapEntry('Asr', t.asr),
            MapEntry('Maghrib', t.maghrib),
            MapEntry('Isha', t.isha),
            if (t.jumuah != null && t.jumuah!.isNotEmpty) MapEntry('Jumuah', t.jumuah!),
          ];

    return Card(
      color: isDark ? const Color(0xFF161B22) : theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time_filled, color: t != null ? const Color(0xFFF59E0B) : Colors.grey, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Jamaat Times', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (canEdit)
                  TextButton(
                    onPressed: onEdit,
                    child: const Text('Edit Times', style: TextStyle(color: Color(0xFF10B981))),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...rows.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    Text(formatHhmm(e.value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t != null ? const Color(0xFFF59E0B) : null)),
                  ],
                ),
              );
            }),
            if (t == null) ...[
              const SizedBox(height: 8),
              Text(
                'Showing calculated times.',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Shared widgets & helpers
// ─────────────────────────────────────────────────────────────────────────

String formatHhmm(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.first) ?? 0;
  final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$hour12:$m ${h >= 12 ? 'PM' : 'AM'}';
}

String formatDateTime(DateTime dt) {
  final d = dt.toLocal();
  final hh = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
  final mm = d.minute.toString().padLeft(2, '0');
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]}, $hh:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
}

class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({
    super.key,
    required this.announcement,
    this.canDelete = false,
  });

  final CloudAnnouncement announcement;
  final bool canDelete;

  Future<void> _delete(BuildContext context) async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await scope.supabaseService.deleteAnnouncement(announcement.id);
      await scope.sync.refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final a = announcement;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? const Color(0xFF161B22) : theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(a.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _delete(context),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(a.content, style: TextStyle(height: 1.4, color: theme.colorScheme.onSurface.withValues(alpha: 0.85))),
            const SizedBox(height: 12),
            Text(
              formatDateTime(a.createdAt),
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showAnnouncementComposer(
  BuildContext context, {
  required String cloudMosqueId,
}) async {
  final scope = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New Announcement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Details', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true), 
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          child: const Text('Post'),
        ),
      ],
    ),
  );

  final title = titleCtrl.text.trim();
  final body = bodyCtrl.text.trim();
  if (ok != true) return false;
  if (title.isEmpty || body.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text('Title and details are required.')));
    return false;
  }
  try {
    await scope.supabaseService.createAnnouncement(
      cloudMosqueId: cloudMosqueId,
      title: title,
      content: body,
    );
    await scope.sync.refresh();
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Failed to post: $e')));
    return false;
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.live});
  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = live ? const Color(0xFF10B981) : Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(live ? 'LIVE' : 'Offline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
