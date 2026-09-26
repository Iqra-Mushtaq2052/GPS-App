import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/auth/auth_service.dart';
import '../../core/supabase/supabase_service.dart';
import '../../data/db/app_database.dart';
import 'add_mosque_page.dart';
import 'discover_mosques_page.dart';
import 'mosque_detail_page.dart';

/// "Meri Masajid" — downloaded mosques (everyone) + managed mosques
/// (imam / committee accounts).
class MosqueListPage extends StatefulWidget {
  const MosqueListPage({super.key});

  @override
  State<MosqueListPage> createState() => _MosqueListPageState();
}

class _MosqueListPageState extends State<MosqueListPage> {
  bool _isImamRole = false;
  bool _roleLoaded = false;
  bool _loadingManaged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final scope = AppScope.of(context);
    final isImam = await scope.roleService.isImam();
    if (!mounted) return;
    setState(() {
      _isImamRole = isImam;
      _roleLoaded = true;
    });
    if (isImam) await _refreshManaged();
  }

  Future<void> _refreshManaged() async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loadingManaged = true);
    try {
      await scope.auth.refreshStatus(createIfMissing: true);
      await scope.sync.refreshManaged();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyCloudError(e))));
    } finally {
      if (mounted) setState(() => _loadingManaged = false);
    }
  }

  Future<void> _deleteManaged(ManagedMosque m) async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masjid delete karein?'),
        content: Text(
          '"${m.name}" cloud se hamesha ke liye delete ho jayegi. Is ke jamaat times, '
          'announcements aur committee bhi khatam ho jayenge, aur ${m.followerCount} namaziyon ke '
          'phone se bhi hat jayegi.',
        ),
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
      await scope.sync.deleteManagedMosque(m.id);
      messenger.showSnackBar(SnackBar(content: Text('"${m.name}" delete ho gayi.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyCloudError(e))));
    }
  }

  void _openLocal(Mosque m) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MosqueDetailPage(mosque: m)));
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);

    if (!_roleLoaded) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isImamRole ? 'Masjid Management' : 'Meri Masajid'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              if (_isImamRole) await _refreshManaged();
              await scope.sync.refresh();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DiscoverMosquesPage()),
        ),
        icon: const Icon(Icons.storefront),
        label: const Text('Masjid Store'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([scope.sync, scope.auth]),
        builder: (context, _) {
          final managed = scope.sync.managedMosques;
          final managedIds = managed.map((m) => m.id).toSet();

          return StreamBuilder<List<Mosque>>(
            stream: scope.mosqueRepository.watchAll(),
            builder: (context, snapshot) {
              final local = snapshot.data ?? const <Mosque>[];
              final downloaded = local.where((m) => !managedIds.contains(m.supabaseId)).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  if (_isImamRole) ...[
                    _ImamStatusCard(status: scope.auth.status, email: scope.auth.email),
                    const SizedBox(height: 12),
                    _SectionTitle(
                      icon: Icons.admin_panel_settings,
                      text: 'Meri masjid (management)',
                      trailing: _loadingManaged
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : null,
                    ),
                    if (managed.isEmpty && !_loadingManaged)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          scope.auth.isApprovedImam
                              ? 'Abhi aap ne koi masjid register nahi ki.'
                              : 'Approval ke baad aap masjid register kar sakenge. Agar aap committee member hain '
                                  'to Imam aap ki email ko committee mein add karega.',
                          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
                        ),
                      ),
                    ...managed.map((m) {
                      final localCopy = scope.sync.localFor(m.id);
                      return _ManagedTile(
                        mosque: m,
                        times: scope.sync.timesFor(m.id),
                        onOpen: localCopy == null ? null : () => _openLocal(localCopy),
                        onDelete: m.isImam ? () => _deleteManaged(m) : null,
                      );
                    }),
                    if (scope.auth.isApprovedImam) ...[
                      const SizedBox(height: 4),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddMosquePage()),
                        ),
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Nayi masjid register karein'),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                  _SectionTitle(icon: Icons.download_done, text: 'Downloaded masajid (${downloaded.length})'),
                  if (downloaded.isEmpty)
                    _EmptyDownloaded(onOpenStore: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DiscoverMosquesPage()),
                        ))
                  else
                    ...downloaded.map((m) => _DownloadedTile(
                          mosque: m,
                          times: scope.sync.timesFor(m.supabaseId),
                          onOpen: () => _openLocal(m),
                          onToggle: (v) async {
                            await scope.mosqueRepository.update(m.copyWith(isEnabled: v));
                            await scope.sync.onLocalMosquesChanged?.call();
                          },
                          onRemove: m.supabaseId == null
                              ? () async {
                                  await scope.sync.removeDownloaded(m);
                                }
                              : null,
                        )),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Next jamaat label like "Asr 5:15 PM".
String? nextJamaatLabel(CloudPrayerTimes? t) {
  if (t == null) return null;
  final now = DateTime.now();
  const labels = ['Fajr', 'Zuhr', 'Asr', 'Maghrib', 'Isha'];
  final raw = [t.fajr, t.dhuhr, t.asr, t.maghrib, t.isha];
  final dts = t.toTodayDateTimes().values.toList();
  for (var i = 0; i < dts.length; i++) {
    if (dts[i].isAfter(now)) return '${labels[i]} ${formatHhmm(raw[i])}';
  }
  return 'Fajr ${formatHhmm(t.fajr)}';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text, this.trailing});
  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ?trailing,
        ],
      ),
    );
  }
}

class _ImamStatusCard extends StatelessWidget {
  const _ImamStatusCard({required this.status, required this.email});
  final ImamStatus status;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String title, String body) = switch (status) {
      ImamStatus.approved => (
          const Color(0xFF10B981),
          Icons.verified,
          'Imam account approved',
          'Aap masjid register kar sakte hain.',
        ),
      ImamStatus.pending => (
          Colors.orange,
          Icons.hourglass_top,
          'Approval pending',
          'Admin aap ki details check kar raha hai. Approval ke baad masjid register kar sakenge.',
        ),
      ImamStatus.rejected => (
          Colors.redAccent,
          Icons.block,
          'Request reject ho gayi',
          'Tafseel ke liye admin se rabta karein.',
        ),
      ImamStatus.none => (
          Colors.grey,
          Icons.person_outline,
          'Profile nahi mili',
          'Refresh karein ya dobara login karein.',
        ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(fontSize: 12)),
                if (email != null)
                  Text(email!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagedTile extends StatelessWidget {
  const _ManagedTile({required this.mosque, required this.times, this.onOpen, this.onDelete});
  final ManagedMosque mosque;
  final CloudPrayerTimes? times;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = nextJamaatLabel(times);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mosque, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mosque.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          '${mosque.isImam ? 'Imam' : 'Committee'} • ${mosque.followerCount} followers'
                          '${next != null ? ' • Agli jamaat: $next' : ''}',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'Masjid delete',
                      onPressed: onDelete,
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: mosque.shareCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Share code "${mosque.shareCode}" copy ho gaya')),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.vpn_key, size: 14, color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text('Share code: ${mosque.shareCode}',
                        style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Icon(Icons.copy, size: 14, color: theme.colorScheme.secondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadedTile extends StatelessWidget {
  const _DownloadedTile({
    required this.mosque,
    required this.times,
    required this.onOpen,
    required this.onToggle,
    this.onRemove,
  });

  final Mosque mosque;
  final CloudPrayerTimes? times;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = nextJamaatLabel(times);
    final isCloud = mosque.supabaseId != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onOpen,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          child: Icon(Icons.mosque, color: theme.colorScheme.primary),
        ),
        title: Text(mosque.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          isCloud
              ? (next != null ? 'Agli jamaat: $next' : 'Jamaat times abhi set nahi')
              : 'Purani local entry (cloud se connected nahi)',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRemove != null)
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: onRemove),
            Switch(value: mosque.isEnabled, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

class _EmptyDownloaded extends StatelessWidget {
  const _EmptyDownloaded({required this.onOpenStore});
  final VoidCallback onOpenStore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.storefront, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            'Abhi koi masjid download nahi ki.\nMasjid Store mein 5–10 km ke andar ki registered masajid dekhein.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.65), height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpenStore,
            icon: const Icon(Icons.storefront),
            label: const Text('Masjid Store kholein'),
          ),
        ],
      ),
    );
  }
}
