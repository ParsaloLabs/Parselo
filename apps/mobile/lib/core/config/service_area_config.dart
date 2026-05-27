import 'dart:math' as math;
import '../network/api_client.dart';

class ServiceArea {
  final String name;
  final double centerLat;
  final double centerLng;
  final int radiusM;

  const ServiceArea({
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusM,
  });
}

/// Active service-area zones from `GET /config/service-areas`. Cached after
/// first fetch so the pickup/delivery picker can validate synchronously.
/// Falls back to a hardcoded Thrissur zone (matches db/migrations/0010 seed)
/// so the gate works even on a cold offline launch — fail-safe inward, not
/// fail-open outward.
class ServiceAreaConfig {
  ServiceAreaConfig._();
  static final ServiceAreaConfig instance = ServiceAreaConfig._();

  static const List<ServiceArea> _fallback = [
    ServiceArea(name: 'Thrissur', centerLat: 10.5276, centerLng: 76.2144, radiusM: 15000),
  ];

  List<ServiceArea> _areas = _fallback;
  bool _loaded = false;
  bool get isLoaded => _loaded;
  List<ServiceArea> get areas => List.unmodifiable(_areas);

  Future<void> load() async {
    try {
      final res = await ApiClient.request('/config/service-areas', auth: false);
      if (res is Map && res['areas'] is List) {
        final parsed = <ServiceArea>[];
        for (final item in (res['areas'] as List)) {
          if (item is! Map) continue;
          final name = item['name'];
          final lat = (item['center_lat'] as num?)?.toDouble();
          final lng = (item['center_lng'] as num?)?.toDouble();
          final radius = (item['radius_m'] as num?)?.toInt();
          if (name is String && lat != null && lng != null && radius != null) {
            parsed.add(ServiceArea(
              name: name,
              centerLat: lat,
              centerLng: lng,
              radiusM: radius,
            ));
          }
        }
        if (parsed.isNotEmpty) {
          _areas = parsed;
        }
        _loaded = true;
      }
    } catch (_) {
      // Stay on fallback; fail-safe so Thrissur still works offline.
    }
  }

  bool isInside(double lat, double lng) {
    for (final a in _areas) {
      if (_distanceMeters(lat, lng, a.centerLat, a.centerLng) <= a.radiusM) {
        return true;
      }
    }
    return false;
  }

  ServiceArea? nearest(double lat, double lng) {
    if (_areas.isEmpty) return null;
    ServiceArea best = _areas.first;
    double bestD = _distanceMeters(lat, lng, best.centerLat, best.centerLng);
    for (final a in _areas.skip(1)) {
      final d = _distanceMeters(lat, lng, a.centerLat, a.centerLng);
      if (d < bestD) {
        bestD = d;
        best = a;
      }
    }
    return best;
  }

  static double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double toRad(double d) => d * math.pi / 180.0;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }
}
