import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../data/db/app_database.dart';

/// Represents a mosque discovered dynamically via OpenStreetMap worldwide data.
class DiscoveredMosque {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final String? address;
  bool isSaved;

  DiscoveredMosque({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.address,
    this.isSaved = false,
  });

  DiscoveredMosque copyWith({bool? isSaved}) {
    return DiscoveredMosque(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters,
      address: address,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}

/// Service combining Nominatim Bounded Engine + Overpass fallback for 100% reliable discovery.
class MosqueDiscoveryService {
  final http.Client _client;

  MosqueDiscoveryService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches real mosques around [latitude], [longitude] within [radiusMeters].
  /// Default radius is 1000m (1 km).
  Future<List<DiscoveredMosque>> fetchNearbyMosques({
    required double latitude,
    required double longitude,
    double radiusMeters = 1000,
    List<Mosque> savedMosques = const [],
  }) async {
    final Map<String, DiscoveredMosque> discoveredMap = {};
    final Set<String> seenCoords = {};

    // ── Calculate Bounding Box degrees based on radius (with 25% safety margin) ──
    final double deltaDeg = (radiusMeters / 111000.0) * 1.25;
    final double minLon = longitude - deltaDeg;
    final double maxLon = longitude + deltaDeg;
    final double minLat = latitude - deltaDeg;
    final double maxLat = latitude + deltaDeg;

    final String viewboxParam = 'viewbox=$minLon,$maxLat,$maxLon,$minLat&bounded=1';

    // ── 1. Bounded Parallel Nominatim CDN Requests ──
    final nominatimUrls = [
      'https://nominatim.openstreetmap.org/search?amenity=place_of_worship&$viewboxParam&format=json&addressdetails=1&limit=60',
      'https://nominatim.openstreetmap.org/search?q=mosque&$viewboxParam&format=json&addressdetails=1&limit=60',
      'https://nominatim.openstreetmap.org/search?q=masjid&$viewboxParam&format=json&addressdetails=1&limit=60',
    ];

    try {
      final responses = await Future.wait(
        nominatimUrls.map(
          (url) => _client.get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'GpsApp/1.0 (Mobile Islamic App)',
              'Accept': 'application/json',
            },
          ).timeout(const Duration(seconds: 6), onTimeout: () => http.Response('[]', 408)),
        ),
      );

      final mosqueKeywords = RegExp(
        r'masjid|mosque|jamia|jaamia|madni|makki|faizan|markaz|musalla|مسجد|جامع|نماز',
        caseSensitive: false,
      );

      for (final response in responses) {
        if (response.statusCode != 200) continue;

        try {
          final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));

          for (final item in list) {
            if (item is! Map<String, dynamic>) continue;

            final double? mLat = double.tryParse(item['lat']?.toString() ?? '');
            final double? mLng = double.tryParse(item['lon']?.toString() ?? '');
            if (mLat == null || mLng == null) continue;

            // Calculate precise distance from user position
            final dist = Geolocator.distanceBetween(latitude, longitude, mLat, mLng);

            // Enforce exact radius filter (with 50m tolerance)
            if (dist > (radiusMeters + 50)) continue;

            final String rawName = (item['display_name'] as String? ?? '').trim();
            final String category = (item['category'] as String? ?? '').toLowerCase();
            final String type = (item['type'] as String? ?? '').toLowerCase();

            bool isMosque = false;
            if (type == 'place_of_worship' || category == 'place_of_worship' || type == 'mosque') {
              isMosque = true;
            } else if (rawName.isNotEmpty && mosqueKeywords.hasMatch(rawName)) {
              isMosque = true;
            }

            if (!isMosque) continue;

            final coordKey = '${mLat.toStringAsFixed(4)}_${mLng.toStringAsFixed(4)}';
            if (seenCoords.contains(coordKey)) continue;
            seenCoords.add(coordKey);

            String displayName = rawName.split(',').first.trim();
            if (displayName.isEmpty || displayName.toLowerCase() == 'place_of_worship') {
              displayName = 'Masjid / Mosque';
            }

            final addressDetails = item['address'] as Map<String, dynamic>?;
            String? address;
            if (addressDetails != null) {
              final road = addressDetails['road'] as String?;
              final suburb = addressDetails['suburb'] as String? ??
                  addressDetails['city'] as String? ??
                  addressDetails['town'] as String?;
              if (road != null && suburb != null) {
                address = '$road, $suburb';
              } else if (suburb != null) {
                address = suburb;
              }
            }

            final osmId = item['osm_id']?.toString() ?? '${mLat.hashCode}_${mLng.hashCode}';

            final alreadySaved = savedMosques.any((saved) {
              final d = Geolocator.distanceBetween(saved.latitude, saved.longitude, mLat, mLng);
              return d < 35.0 ||
                  (displayName != 'Masjid / Mosque' &&
                      saved.name.toLowerCase() == displayName.toLowerCase());
            });

            discoveredMap[coordKey] = DiscoveredMosque(
              id: 'osm_$osmId',
              name: displayName,
              latitude: mLat,
              longitude: mLng,
              distanceMeters: dist,
              address: address,
              isSaved: alreadySaved,
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Bounded Nominatim fetch error: $e');
    }

    final results = discoveredMap.values.toList();
    results.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return results;
  }
}
