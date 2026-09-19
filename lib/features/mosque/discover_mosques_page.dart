import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app_scope.dart';
import '../../core/discovery/mosque_discovery_service.dart';
import 'join_mosque_page.dart';

class DiscoverMosquesPage extends StatefulWidget {
  const DiscoverMosquesPage({super.key});

  @override
  State<DiscoverMosquesPage> createState() => _DiscoverMosquesPageState();
}

class _DiscoverMosquesPageState extends State<DiscoverMosquesPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Position? _currentPos;
  List<DiscoveredMosque> _mosques = [];
  double _searchRadiusMeters = 1000; // Default 1 km
  bool _isAddingAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _discoverMosques());
  }

  Future<void> _discoverMosques() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final scope = AppScope.of(context);
    try {
      if (!await scope.location.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'GPS / Location is turned off. Please turn on Location first.';
          });
        }
        return;
      }

      var permission = await scope.location.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await scope.location.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Location permission is required to detect nearby mosques.';
          });
        }
        return;
      }

      // Fresh live position fetch
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (_) {
        pos = await scope.location.getQuickPosition();
      }

      if (pos == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Could not get GPS position. Make sure GPS is enabled.';
          });
        }
        return;
      }

      final saved = await scope.mosqueRepository.getAll();

      final discovered = await scope.discovery.fetchNearbyMosques(
        latitude: pos.latitude,
        longitude: pos.longitude,
        radiusMeters: _searchRadiusMeters,
        savedMosques: saved,
      );

      if (mounted) {
        setState(() {
          _currentPos = pos;
          _mosques = discovered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not fetch nearby mosques: $e';
        });
      }
    }
  }

  Future<void> _saveMosque(DiscoveredMosque mosque) async {
    final scope = AppScope.of(context);
    final isImam = await scope.roleService.isImam();

    if (!isImam) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Imam Code Required'),
            ],
          ),
          content: Text(
            'Only Imams can register new mosques.\n\nTo add "${mosque.name}" to your auto-silent list, please enter the 6-character Share Code provided by the Imam of this mosque.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              icon: const Icon(Icons.pin_outlined, size: 18),
              label: const Text('Enter Share Code'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JoinMosquePage()),
                );
              },
            ),
          ],
        ),
      );
      return;
    }

    try {
      // Imam claims & registers mosque with share code via uploadMosque
      String? cloudId;
      String? shareCode;
      try {
        final uploaded = await scope.supabaseService.uploadMosque(
          name: mosque.name,
          latitude: mosque.latitude,
          longitude: mosque.longitude,
          radiusMeters: 40,
        );
        cloudId = uploaded.id;
        shareCode = uploaded.shareCode;
      } catch (_) {
        // Offline fallback
      }

      await scope.mosqueRepository.add(
        name: mosque.name,
        latitude: mosque.latitude,
        longitude: mosque.longitude,
        radiusMeters: 40,
        supabaseId: cloudId,
        shareCode: shareCode,
      );

      await scope.proximity.refreshMosques();

      if (mounted) {
        setState(() {
          mosque.isSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shareCode != null
                  ? '✅ "${mosque.name}" registered! Share Code: $shareCode'
                  : '✅ "${mosque.name}" registered locally!',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _saveAllUnsaved() async {
    final scope = AppScope.of(context);
    final isImam = await scope.roleService.isImam();

    if (!isImam) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Imams can register mosques. Users join via Share Code.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final unsaved = _mosques.where((m) => !m.isSaved).toList();
    if (unsaved.isEmpty) return;

    setState(() => _isAddingAll = true);

    int addedCount = 0;
    for (final m in unsaved) {
      try {
        String? cloudId;
        String? shareCode;
        try {
          final uploaded = await scope.supabaseService.uploadMosque(
            name: m.name,
            latitude: m.latitude,
            longitude: m.longitude,
            radiusMeters: 40,
          );
          cloudId = uploaded.id;
          shareCode = uploaded.shareCode;
        } catch (_) {}

        await scope.mosqueRepository.add(
          name: m.name,
          latitude: m.latitude,
          longitude: m.longitude,
          radiusMeters: 40,
          supabaseId: cloudId,
          shareCode: shareCode,
        );
        m.isSaved = true;
        addedCount++;
      } catch (_) {}
    }

    await scope.proximity.refreshMosques();

    if (mounted) {
      setState(() => _isAddingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Registered $addedCount mosques with Share Codes!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m away';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unsavedCount = _mosques.where((m) => !m.isSaved).length;

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
        title: const Text('Discover Nearby Mosques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Nearby',
            onPressed: _discoverMosques,
          ),
        ],
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
        child: Column(
          children: [
            // ── GPS Position Banner ──
            if (_currentPos != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'GPS Position: ${_currentPos!.latitude.toStringAsFixed(4)}°, ${_currentPos!.longitude.toStringAsFixed(4)}°',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Search Radius Options Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.radar, size: 20, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  const Text('Search Radius:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 12),
                  Row(
                    children: [1000.0, 3000.0].map((rad) {
                      final label = rad >= 1000 ? '${(rad / 1000).round()} km' : '${rad.round()}m';
                      final isSelected = _searchRadiusMeters == rad;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _searchRadiusMeters = rad);
                              _discoverMosques();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // ── Main Content Body ──
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: theme.colorScheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            'Scanning nearby mosques within ${_searchRadiusMeters >= 1000 ? "${(_searchRadiusMeters / 1000).round()} km" : "${_searchRadiusMeters.round()}m"}...',
                            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off, size: 56, color: Colors.orangeAccent),
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _discoverMosques,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _mosques.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_searching, size: 56, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No registered mosques found in this ${_searchRadiusMeters >= 1000 ? "${(_searchRadiusMeters / 1000).round()} km" : "${_searchRadiusMeters.round()}m"} circle.',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try searching within 3 km.',
                                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), height: 1.4),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    FilledButton.icon(
                                      onPressed: () {
                                        setState(() => _searchRadiusMeters = 3000);
                                        _discoverMosques();
                                      },
                                      icon: const Icon(Icons.zoom_out_map, size: 18),
                                      label: const Text('Search 3 km Radius'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _discoverMosques,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _mosques.length,
                                itemBuilder: (context, index) {
                                  final m = _mosques[index];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: m.isSaved
                                            ? const Color(0xFF10B981).withValues(alpha: 0.6)
                                            : theme.dividerColor,
                                        width: m.isSaved ? 1.5 : 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Mosque Circle Avatar Icon
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: m.isSaved
                                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                  : theme.colorScheme.secondary.withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.mosque,
                                              color: m.isSaved
                                                  ? const Color(0xFF10B981)
                                                  : theme.colorScheme.secondary,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // Mosque Name, Distance & Address (Fully Constrained via Expanded)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  m.name,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.near_me,
                                                      size: 13,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _formatDistance(m.distanceMeters),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: theme.colorScheme.primary,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (m.address != null) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    m.address!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),

                                          // Action Button (Saved Badge or + Auto-Silent)
                                          m.isSaved
                                              ? Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: const Color(0xFF10B981)),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        'Saved',
                                                        style: TextStyle(
                                                          color: Color(0xFF10B981),
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : FilledButton(
                                                  onPressed: () => _saveMosque(m),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: theme.colorScheme.primary,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.add, size: 15),
                                                      SizedBox(width: 3),
                                                      Text('Auto-Silent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),

            // ── Add All Footer Button ──
            if (!_isLoading && _mosques.isNotEmpty && unsavedCount > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isAddingAll ? null : _saveAllUnsaved,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isAddingAll
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.playlist_add_check),
                    label: Text(
                      _isAddingAll ? 'Saving All...' : 'Add All $unsavedCount Nearby Mosques',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
