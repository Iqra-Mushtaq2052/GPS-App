import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/supabase/supabase_service.dart';

/// Imam manages the committee of a mosque. Committee members can update
/// jamaat times and post announcements, but cannot edit / delete the mosque
/// or change the committee. A mosque has exactly one imam.
class CommitteePage extends StatefulWidget {
  const CommitteePage({super.key, required this.mosque});

  final ManagedMosque mosque;

  @override
  State<CommitteePage> createState() => _CommitteePageState();
}

class _CommitteePageState extends State<CommitteePage> {
  List<CommitteeMember> _members = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AppScope.of(context).supabaseService.listCommittee(widget.mosque.id);
      if (mounted) setState(() => _members = list);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyCloudError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final emailCtrl = TextEditingController();
    final titleCtrl = TextEditingController(text: 'Committee Member');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Committee member add karein'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Member pehle app mein "Imam / Committee" se apna account banaye. '
              'Phir us ki email yahan likhein.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Ohda (maslan: Muazzin, Mutawalli)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    final email = emailCtrl.text.trim();
    final title = titleCtrl.text.trim();
    if (ok != true || email.isEmpty) return;

    try {
      await scope.supabaseService.addCommitteeMember(
        cloudMosqueId: widget.mosque.id,
        email: email,
        title: title.isEmpty ? 'Committee Member' : title,
      );
      messenger.showSnackBar(SnackBar(content: Text('$email committee mein add ho gaya.')));
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyCloudError(e))));
    }
  }

  Future<void> _remove(CommitteeMember m) async {
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Member hatayein?'),
        content: Text('${m.fullName.isNotEmpty ? m.fullName : m.email} ab is masjid ko manage nahi kar sakega.'),
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
    try {
      await scope.supabaseService.removeCommitteeMember(cloudMosqueId: widget.mosque.id, userId: m.userId);
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyCloudError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Committee — ${widget.mosque.name}', overflow: TextOverflow.ellipsis)),
      floatingActionButton: widget.mosque.isImam
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.person_add),
              label: const Text('Member add'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Dobara koshish')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: [
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('Masjid ka Imam ek hi hota hai'),
                          subtitle: Text(
                            'Committee members jamaat times aur announcements update kar sakte hain. '
                            'Masjid edit/delete aur committee ka intezam sirf Imam ke paas hai.',
                            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_members.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Abhi koi committee member nahi.', textAlign: TextAlign.center),
                        )
                      else
                        ..._members.map((m) => Card(
                              child: ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(m.fullName.isNotEmpty ? m.fullName : m.email),
                                subtitle: Text('${m.title} • ${m.email}'),
                                trailing: widget.mosque.isImam
                                    ? IconButton(
                                        icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                                        onPressed: () => _remove(m),
                                      )
                                    : null,
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }
}
