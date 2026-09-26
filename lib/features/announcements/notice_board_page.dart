import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/supabase/supabase_service.dart';
import '../mosque/mosque_detail_page.dart';

/// All announcements from every connected mosque, live.
/// Imam / committee can post to the mosques they manage.
class NoticeBoardPage extends StatefulWidget {
  const NoticeBoardPage({super.key});

  @override
  State<NoticeBoardPage> createState() => _NoticeBoardPageState();
}

class _NoticeBoardPageState extends State<NoticeBoardPage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      AppScope.of(context).sync.refresh();
    }
  }

  Future<void> _post(List<ManagedMosque> managed) async {
    String? target = managed.length == 1 ? managed.first.id : null;
    target ??= await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Kis masjid ke liye?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...managed.map(
              (m) => ListTile(
                leading: const Icon(Icons.mosque),
                title: Text(m.name),
                onTap: () => Navigator.pop(ctx, m.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    final posted = await showAnnouncementComposer(
      context,
      cloudMosqueId: target,
    );
    if (posted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement post ho gayi!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final sync = scope.sync;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final anns = sync.announcementsFor();
        final managed = sync.managedMosques;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notice Board'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: sync.refresh,
              ),
            ],
          ),
          floatingActionButton: managed.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () => _post(managed),
                  icon: const Icon(Icons.add_comment),
                  label: const Text('Announcement'),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: sync.refresh,
            child: anns.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Icon(
                        Icons.campaign_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          sync.lastError != null
                              ? 'Offline — ${sync.lastError}'
                              : 'Aap ki masajid se abhi koi announcement nahi.\n'
                                    'Masjid Store se masjid download karein — Imam ki announcements yahan live aayengi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: anns.length,
                    itemBuilder: (context, i) {
                      final a = anns[i];
                      return AnnouncementTile(
                        announcement: a,
                        canDelete: sync.isManaged(a.mosqueId),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
