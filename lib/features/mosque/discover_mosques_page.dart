import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app_scope.dart';
import '../../core/supabase/supabase_service.dart';
import 'join_mosque_page.dart';
import 'mosque_detail_page.dart';

class DiscoverMosquesPage extends StatefulWidget {
  const DiscoverMosquesPage({super.key});

  @override
  State<DiscoverMosquesPage> createState() => _DiscoverMosquesPageState();
}

class _DiscoverMosquesPageState extends State<DiscoverMosquesPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<StoreMosque> _mosques = [];
  double _radiusKm = 5.0; // Default to 5 km
  final Set<String> _downloading = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  double? _debugLat;
  double? _debugLng;
  String? _debugDetail; // extra diagnostic info shown in empty state

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _debugDetail = null;
    });

    final scope = AppScope.of(context);
    try {
      if (!await scope.location.isLocationServiceEnabled()) {
        _fail('GPS / Location is OFF. Please enable Location in phone settings.');
        return;
      }
      var permission = await scope.location.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await scope.location.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _fail('Location permission required to search nearby mosques.');
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        pos = await scope.location.getQuickPosition();
      }
      if (pos == null) {
        _fail('Could not get GPS position. Make sure GPS is ON and try again.');
        return;
      }

      // Log GPS coordinates so we can verify the fix is accurate
      debugPrint('[Discover] GPS fix: lat=${pos.latitude}, lng=${pos.longitude}, acc=${pos.accuracy}m');

      List<StoreMosque> list;
      try {
        list = await scope.supabaseService.nearbyMosques(
          latitude: pos.latitude,
          longitude: pos.longitude,
          radiusKm: _radiusKm,
        );
        debugPrint('[Discover] RPC returned ${list.length} mosques within ${_radiusKm}km of (${pos.latitude}, ${pos.longitude})');
      } catch (rpcErr) {
        debugPrint('[Discover] RPC error: $rpcErr');
        _fail('Search failed: ${friendlyCloudError(rpcErr)}\n\nRaw: $rpcErr');
        return;
      }

      if (mounted) {
        setState(() {
          _mosques = list;
          _isLoading = false;
          _debugLat = pos!.latitude;
          _debugLng = pos.longitude;
          _debugDetail = list.isEmpty
              ? 'Your GPS: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}\n'
                  'Search radius: ${_radiusKm}km\n'
                  'No registered mosques found in this area.\n\n'
                  'If you just registered a mosque, make sure the PostGIS location trigger ran:\n'
                  'Run in Supabase SQL Editor:\n'
                  'UPDATE mosques SET latitude=latitude WHERE imam_user_id=auth.uid();'
              : null;
        });
      }
    } catch (e) {
      debugPrint('[Discover] Unexpected error: $e');
      _fail('Unexpected error: ${friendlyCloudError(e)}');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  Future<void> _download(StoreMosque m) async {
    if (_downloading.contains(m.id)) return;
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _downloading.add(m.id));
    try {
      await scope.sync.downloadMosque(m);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Downloaded! Mosque added to My Masajid.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Download failed: ${friendlyCloudError(e)}')));
    } finally {
      if (mounted) setState(() => _downloading.remove(m.id));
    }
  }

  void _openDetail(StoreMosque m, bool isDownloaded) {
    if (isDownloaded) {
      final local = AppScope.of(context).sync.localFor(m.id);
      if (local != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MosqueDetailPage(mosque: local)),
        );
      }
    } else {
      _showPreviewSheet(m);
    }
  }

  void _showPreviewSheet(StoreMosque m) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                m.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (m.address != null && m.address!.isNotEmpty)
                Text(
                  m.address!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text('${m.followerCount} followers'),
                  const SizedBox(width: 16),
                  const Icon(Icons.map, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(_formatDistance(m.distanceMeters)),
                ],
              ),
              const SizedBox(height: 24),
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setStateSheet) {
                  final bool busy = _downloading.contains(m.id);
                  return FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await _download(m);
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Download',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  );
                }
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MosqueDetailPage(cloudMosque: m),
                    ),
                  );
                },
                child: const Text('View Full Details'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDistance(double meters) =>
      meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Nearby Mosques'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JoinMosquePage()),
                    ),
                    icon: const Icon(Icons.pin_outlined),
                    label: const Text('Join by Code'),
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.grey[200],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _RadiusChip(
                  label: '5 km',
                  selected: _radiusKm == 5.0,
                  onTap: () {
                    if (_radiusKm != 5.0 && !_isLoading) {
                      setState(() => _radiusKm = 5.0);
                      _load();
                    }
                  },
                ),
                const SizedBox(width: 8),
                _RadiusChip(
                  label: '10 km',
                  selected: _radiusKm == 10.0,
                  onTap: () {
                    if (_radiusKm != 10.0 && !_isLoading) {
                      setState(() => _radiusKm = 10.0);
                      _load();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF10B981)),
            const SizedBox(height: 16),
            Text('Searching within ${_radiusKm.round()} km...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            color: Colors.redAccent.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_mosques.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No mosques found within ${_radiusKm.round()} km.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_debugLat != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Your GPS: ${_debugLat!.toStringAsFixed(5)}, ${_debugLng!.toStringAsFixed(5)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'monospace'),
                ),
              ],
              if (_radiusKm < 10.0) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _radiusKm = 10.0);
                    _load();
                  },
                  icon: const Icon(Icons.radar),
                  label: const Text('Expand to 10 km'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                ),
              ],
              if (_debugDetail != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bug_report, color: Colors.amber, size: 16),
                          SizedBox(width: 6),
                          Text('Debug Info', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _debugDetail!,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final sync = AppScope.of(context).sync;
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF10B981),
      child: ListenableBuilder(
        listenable: sync,
        builder: (context, _) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _mosques.length,
          itemBuilder: (context, index) {
            final m = _mosques[index];
            final downloaded = sync.isDownloaded(m.id);
            final busy = _downloading.contains(m.id);
            return _MosqueCard(
              mosque: m,
              distance: _formatDistance(m.distanceMeters),
              downloaded: downloaded,
              busy: busy,
              onDownload: () => _download(m),
              onTap: () => _openDetail(m, downloaded),
            );
          },
        ),
      ),
    );
  }
}

class _RadiusChip extends StatelessWidget {
  const _RadiusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected ? const Color(0xFF10B981) : Colors.transparent,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF10B981) : Colors.grey,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _MosqueCard extends StatelessWidget {
  const _MosqueCard({
    required this.mosque,
    required this.distance,
    required this.downloaded,
    required this.busy,
    required this.onDownload,
    required this.onTap,
  });

  final StoreMosque mosque;
  final String distance;
  final bool downloaded;
  final bool busy;
  final VoidCallback onDownload;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: downloaded ? const Color(0xFF10B981).withValues(alpha: 0.5) : (isDark ? const Color(0xFF30363D) : theme.dividerColor),
        ),
      ),
      color: isDark ? const Color(0xFF161B22) : theme.cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(distance, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(width: 12),
                            const Icon(Icons.people, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${mosque.followerCount}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (mosque.hasTimes) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 12, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'Prayer Times Set',
                            style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                  if (!mosque.hasTimes) const Spacer(),
                  if (downloaded)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Downloaded', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    )
                  else
                    FilledButton(
                      onPressed: busy ? null : onDownload,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Download', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
