import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../app_scope.dart';
import '../../core/discovery/mosque_discovery_service.dart';
import '../../data/db/app_database.dart';
import '../mosque/discover_mosques_page.dart';

class MosqueMapPage extends StatefulWidget {
  const MosqueMapPage({super.key});

  @override
  State<MosqueMapPage> createState() => _MosqueMapPageState();
}

class _MosqueMapPageState extends State<MosqueMapPage> {
  final MapController _mapController = MapController();

  Position? _currentPosition;
  List<Mosque> _savedMosques = [];
  List<DiscoveredMosque> _discoveredMosques = [];
  bool _isLoading = true;
  String? _errorMessage;

  double _selectedRadiusMeters = 1000; // Default 1km

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final scope = AppScope.of(context);
    try {
      final saved = await scope.mosqueRepository.getAll();

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

      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _savedMosques = saved;
          _isLoading = false;
        });
      }

      if (pos != null) {
        _discoverNearby(pos.latitude, pos.longitude, saved, _selectedRadiusMeters);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load map data: $e';
        });
      }
    }
  }

  Future<void> _discoverNearby(
    double lat,
    double lng,
    List<Mosque> saved,
    double radiusMeters,
  ) async {
    if (!mounted) return;
    final scope = AppScope.of(context);
    try {
      final discovered = await scope.discovery.fetchNearbyMosques(
        latitude: lat,
        longitude: lng,
        radiusMeters: radiusMeters,
        savedMosques: saved,
      );

      if (mounted) {
        setState(() {
          _discoveredMosques = discovered;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveDiscoveredMosque(DiscoveredMosque dm) async {
    final scope = AppScope.of(context);
    try {
      await scope.mosqueRepository.add(
        name: dm.name,
        latitude: dm.latitude,
        longitude: dm.longitude,
        radiusMeters: 40,
      );
      await scope.proximity.refreshMosques();
      final updatedSaved = await scope.mosqueRepository.getAll();

      if (mounted) {
        setState(() {
          _savedMosques = updatedSaved;
          dm.isSaved = true;
        });
        Navigator.of(context).pop(); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Added "${dm.name}" to Auto-Silent!'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final initialCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : (_savedMosques.isNotEmpty
            ? LatLng(_savedMosques.first.latitude, _savedMosques.first.longitude)
            : const LatLng(24.8607, 67.0011));

    // ── STRICT DISTANCE FILTERING BY SELECTED RADIUS ──
    final filteredSavedMosques = _savedMosques.where((m) {
      if (_currentPosition == null) return true;
      final dist = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        m.latitude,
        m.longitude,
      );
      return dist <= _selectedRadiusMeters;
    }).toList();

    final filteredDiscoveredMosques = _discoveredMosques.where((d) {
      if (d.isSaved) return false;
      if (_currentPosition == null) return d.distanceMeters <= _selectedRadiusMeters;
      final dist = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        d.latitude,
        d.longitude,
      );
      return dist <= _selectedRadiusMeters;
    }).toList();

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
        title: const Text('Mosques & Geofence Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.explore),
            tooltip: 'Discover Mosques List',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DiscoverMosquesPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Map',
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });
                            _loadData();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: initialCenter,
                        initialZoom: _selectedRadiusMeters <= 1000 ? 15.5 : 14.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.gpsapp.gps_app',
                        ),

                        // Radius Boundary Circle around User (shows 1km or 3km boundary!)
                        if (_currentPosition != null)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                radius: _selectedRadiusMeters,
                                useRadiusInMeter: true,
                                color: Colors.blue.withValues(alpha: 0.08),
                                borderColor: Colors.blue.withValues(alpha: 0.6),
                                borderStrokeWidth: 2,
                              ),
                              ...filteredSavedMosques.map((m) {
                                return CircleMarker(
                                  point: LatLng(m.latitude, m.longitude),
                                  radius: m.radiusMeters.toDouble(),
                                  useRadiusInMeter: true,
                                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                  borderColor: const Color(0xFF10B981),
                                  borderStrokeWidth: 2,
                                );
                              }),
                            ],
                          ),

                        // Markers Layer
                        MarkerLayer(
                          markers: [
                            // 1. User current location marker
                            if (_currentPosition != null)
                              Marker(
                                point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                width: 40,
                                height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.25),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.blue, width: 2.5),
                                  ),
                                  child: const Icon(Icons.my_location, color: Colors.blue, size: 20),
                                ),
                              ),

                            // 2. Saved Active Mosques inside Selected Radius (Emerald Green)
                            ...filteredSavedMosques.map((m) {
                              return Marker(
                                point: LatLng(m.latitude, m.longitude),
                                width: 46,
                                height: 46,
                                child: GestureDetector(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (_) => Container(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.mosque, color: Color(0xFF10B981), size: 32),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(m.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                                      Text('Geofence: ${m.radiusMeters}m (Active Auto-Silent)', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.mosque, color: Colors.white, size: 26),
                                  ),
                                ),
                              );
                            }),

                            // 3. Discovered Global Mosques inside Selected Radius (Amber Gold)
                            ...filteredDiscoveredMosques.map((dm) {
                              return Marker(
                                point: LatLng(dm.latitude, dm.longitude),
                                width: 42,
                                height: 42,
                                child: GestureDetector(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                      ),
                                      builder: (_) => Container(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(Icons.mosque, color: theme.colorScheme.secondary, size: 28),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(dm.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                                      Text(
                                                        '${(dm.distanceMeters).round()}m away (OpenStreetMap)',
                                                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 20),
                                            SizedBox(
                                              width: double.infinity,
                                              child: FilledButton.icon(
                                                onPressed: () => _saveDiscoveredMosque(dm),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: const Color(0xFF10B981),
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                icon: const Icon(Icons.add_location_alt),
                                                label: const Text('Add to Auto-Silent List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                        ),
                                      ],
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    child: const Icon(Icons.mosque, color: Colors.white, size: 22),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),

                    // Top Interactive Radius Selector Bar (1 km & 3 km)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161B22) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Legend
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('Saved', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('Nearby', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),

                            // 1 km / 3 km Radius Chips for Map
                            Row(
                              children: [1000.0, 3000.0].map((rad) {
                                final isSelected = _selectedRadiusMeters == rad;
                                final label = rad >= 1000 ? '${(rad / 1000).round()} km' : '${rad.round()}m';
                                return Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      setState(() {
                                        _selectedRadiusMeters = rad;
                                      });
                                      if (_currentPosition != null) {
                                        _discoverNearby(
                                          _currentPosition!.latitude,
                                          _currentPosition!.longitude,
                                          _savedMosques,
                                          rad,
                                        );
                                        _mapController.move(
                                          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                          rad <= 1000 ? 15.5 : 14.0,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isSelected) ...[
                                            const Icon(Icons.check, size: 12, color: Colors.white),
                                            const SizedBox(width: 3),
                                          ],
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? Colors.white : theme.colorScheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
