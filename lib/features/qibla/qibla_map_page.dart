import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../app_scope.dart';
import '../../core/qibla/qibla_service.dart';

class QiblaMapPage extends StatefulWidget {
  const QiblaMapPage({super.key});

  @override
  State<QiblaMapPage> createState() => _QiblaMapPageState();
}

class _QiblaMapPageState extends State<QiblaMapPage> {
  static const LatLng _kaabaCoords = LatLng(21.422487, 39.826206); // Kaaba, Makkah

  Position? _userPosition;
  double _qiblaBearing = 261.0;
  double _distanceToKaabaKm = 0.0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocation());
  }

  Future<void> _loadLocation() async {
    final scope = AppScope.of(context);
    try {
      final pos = await scope.location
          .getQuickPosition()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);

      if (pos != null) {
        final bearing = QiblaService.calculateQiblaBearing(pos.latitude, pos.longitude);
        final distMeters = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          _kaabaCoords.latitude,
          _kaabaCoords.longitude,
        );

        if (mounted) {
          setState(() {
            _userPosition = pos;
            _qiblaBearing = bearing;
            _distanceToKaabaKm = distMeters / 1000;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = 'GPS location unavailable. Please turn on Location.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error getting location: $e';
        });
      }
    }
  }

  String _getDirectionCardinal(double bearing) {
    const directions = ['North', 'North-East', 'East', 'South-East', 'South', 'South-West', 'West', 'North-West'];
    final index = ((bearing + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final userLatLng = _userPosition != null
        ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
        : const LatLng(24.8607, 67.0011);

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
        title: const Text('Qibla Direction (Map Line)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadLocation();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off, size: 56, color: Colors.orangeAccent),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _loadLocation();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // ── Map View ──
                    Expanded(
                      child: Stack(
                        children: [
                          FlutterMap(
                            options: MapOptions(
                              initialCenter: userLatLng,
                              initialZoom: 16.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.gpsapp.gps_app',
                              ),

                              // Polyline pointing straight from User to Kaaba Makkah
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: [userLatLng, _kaabaCoords],
                                    strokeWidth: 4.0,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ],
                              ),

                              MarkerLayer(
                                markers: [
                                  // User Marker
                                  Marker(
                                    point: userLatLng,
                                    width: 44,
                                    height: 44,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.25),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.blue, width: 2.5),
                                      ),
                                      child: const Icon(Icons.my_location, color: Colors.blue, size: 22),
                                    ),
                                  ),

                                  // Kaaba Makkah Marker
                                  Marker(
                                    point: _kaabaCoords,
                                    width: 50,
                                    height: 50,
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
                                      child: const Icon(Icons.mosque, color: Colors.white, size: 28),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Top Info Overlay Pill
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF161B22) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.alt_route, color: Color(0xFF10B981)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Align your room/building with the Gold Line',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          'Works 100% without hardware compass sensor',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Bottom Angle & Distance Card ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
                        border: Border(top: BorderSide(color: theme.dividerColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_qiblaBearing.toStringAsFixed(1)}°',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                              Text(
                                _getDirectionCardinal(_qiblaBearing),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: theme.dividerColor,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_distanceToKaabaKm.toStringAsFixed(0)} km',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              Text(
                                'Distance to Kaaba',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
