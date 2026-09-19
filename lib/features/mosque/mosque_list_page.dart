import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/db/app_database.dart';
import 'add_mosque_page.dart';
import 'imam_prayer_times_page.dart';
import 'join_mosque_page.dart';

class MosqueListPage extends StatefulWidget {
  const MosqueListPage({super.key});

  @override
  State<MosqueListPage> createState() => _MosqueListPageState();
}

class _MosqueListPageState extends State<MosqueListPage> {
  bool _isImam = false;
  bool _roleLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRole());
  }

  Future<void> _checkRole() async {
    final scope = AppScope.of(context);
    final isImam = await scope.roleService.isImam();
    if (mounted) {
      setState(() {
        _isImam = isImam;
        _roleLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scope = AppScope.of(context);

    if (!_roleLoaded) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

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
        title: Text(_isImam ? 'Imam — Mosque Management' : 'My Joined Mosques'),
        actions: [
          IconButton(
            icon: Icon(_isImam ? Icons.add_location_alt : Icons.pin_outlined),
            tooltip: _isImam ? 'Add Mosque' : 'Join Mosque by Code',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _isImam ? const AddMosquePage() : const JoinMosquePage(),
              ),
            ),
          ),
        ],
      ),

      // Floating Action Button strictly adapted to role
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _isImam ? theme.colorScheme.primary : theme.colorScheme.secondary,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _isImam ? const AddMosquePage() : const JoinMosquePage(),
          ),
        ),
        icon: Icon(_isImam ? Icons.add : Icons.pin_outlined),
        label: Text(_isImam ? 'Add Mosque' : 'Join Mosque by Code'),
      ),

      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [Color(0xFF161B22), Color(0xFF0D1117)],
                ),
              )
            : null,
        child: StreamBuilder<List<Mosque>>(
          stream: scope.mosqueRepository.watchAll(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
            }

            final mosques = snapshot.data!;

            if (mosques.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isImam ? Icons.mosque_outlined : Icons.pin_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isImam
                            ? 'No mosques added yet.\nPress "+ Add Mosque" to register your mosque and generate a Share Code for your worshippers.'
                            : 'No mosques joined yet.\nAsk your Imam for their 6-character Share Code and press "Join Mosque by Code".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        icon: Icon(_isImam ? Icons.add : Icons.pin_outlined),
                        label: Text(_isImam ? 'Add Mosque Now' : 'Join Mosque by Code'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _isImam ? theme.colorScheme.primary : theme.colorScheme.secondary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _isImam ? const AddMosquePage() : const JoinMosquePage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: mosques.length,
              itemBuilder: (context, index) {
                final mosque = mosques[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.surface.withValues(alpha: 0.7) : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border(
                      left: BorderSide(
                        color: mosque.isEnabled ? theme.colorScheme.primary : Colors.grey,
                        width: 4,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Top Row: Icon, Title, Subtitle, Actions ──
                        Row(
                          children: [
                            // Mosque Icon
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                              ),
                              child: Icon(Icons.mosque, color: theme.colorScheme.primary, size: 22),
                            ),
                            const SizedBox(width: 12),

                            // Name & Radius
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mosque.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Radius: ${mosque.radiusMeters}m',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Actions: Edit (Imam only), Switch, Delete
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isImam && mosque.supabaseId != null)
                                  IconButton(
                                    icon: Icon(Icons.edit_calendar, color: theme.colorScheme.secondary, size: 22),
                                    tooltip: 'Edit Prayer Times',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(6),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ImamPrayerTimesPage(
                                            mosqueId: mosque.id,
                                            mosqueName: mosque.name,
                                            shareCode: mosque.shareCode ?? '',
                                            cloudMosqueId: mosque.supabaseId!,
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                Switch(
                                  value: mosque.isEnabled,
                                  onChanged: (value) async {
                                    await scope.mosqueRepository.update(mosque.copyWith(isEnabled: value));
                                    await scope.proximity.refreshMosques();
                                  },
                                ),

                                if (_isImam)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                                    tooltip: 'Delete Mosque',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(6),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Mosque?'),
                                          content: Text(
                                            '${mosque.name} will be deleted. Worshippers will no longer be able to sync with this mosque.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await scope.mosqueRepository.delete(mosque.id);
                                        await scope.proximity.refreshMosques();
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),

                        // ── Dedicated Share Code Block (Imam Only) ──
                        if (_isImam && mosque.shareCode != null) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: mosque.shareCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Share Code "${mosque.shareCode}" copied to clipboard!'),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.vpn_key, size: 16, color: theme.colorScheme.secondary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Share Code: ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                      Text(
                                        mosque.shareCode!,
                                        style: TextStyle(
                                          color: theme.colorScheme.secondary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Copy',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.copy, size: 14, color: theme.colorScheme.secondary),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
