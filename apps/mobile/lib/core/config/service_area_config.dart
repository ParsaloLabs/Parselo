import 'dart:math' as math;
import '../network/api_client.dart';

/// Service-area gate, client-side.
///
/// Primary check is district-wise: a pin is in-zone iff its reverse-geocoded
/// district matches a district where we have ≥1 active courier office.
/// Optional 15 km radius is layered on top when admin flips the
/// `service_area_radius_enabled` flag.
///
/// The full office list + flag + serviceable-district set come back in a
/// single /config/courier-offices fetch and live in memory after that, so
/// every pin drop runs synchronously.
class CourierOffice {
  final String id;
  final String courierName;
  final String? name;
  final String? district;
  final String fullAddress;
  final double latitude;
  final double longitude;

  const CourierOffice({
    required this.id,
    required this.courierName,
    this.name,
    this.district,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
  });
}

class RankedOffice {
  final CourierOffice office;
  final double distanceM;

  const RankedOffice(this.office, this.distanceM);
}

class ServiceAreaConfig {
  ServiceAreaConfig._();
  static final ServiceAreaConfig instance = ServiceAreaConfig._();

  static const double serviceRadiusM = 15000;

  // Fallback so a cold offline boot still gates correctly — treats Thrissur
  // town hall as a single pseudo-office. Fail-safe inward, never fail-open.
  static const List<CourierOffice> _fallback = [
    CourierOffice(
      id: 'fallback-thrissur',
      courierName: 'Parsalo',
      name: 'Thrissur HQ',
      district: 'Thrissur',
      fullAddress: 'Thrissur, Kerala',
      latitude: 10.5276,
      longitude: 76.2144,
    ),
  ];

  List<CourierOffice> _offices = _fallback;
  List<String> _districts = const ['thrissur'];
  bool _radiusEnabled = false;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get radiusGateEnabled => _radiusEnabled;
  List<CourierOffice> get offices => List.unmodifiable(_offices);
  List<String> get serviceableDistricts => List.unmodifiable(_districts);

  static String normalizeDistrict(String? d) {
    if (d == null) return '';
    final lower = d.toLowerCase();
    final stripped = lower.replaceAll(RegExp(r'\s+district$'), '');
    return stripped.replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }

  Future<void> load() async {
    try {
      final res = await ApiClient.request('/config/courier-offices', auth: false);
      if (res is Map && res['offices'] is List) {
        final parsed = <CourierOffice>[];
        for (final item in (res['offices'] as List)) {
          if (item is! Map) continue;
          final id = item['id'];
          final courierName = item['courier_name'];
          final fullAddress = item['full_address'];
          final lat = (item['latitude'] as num?)?.toDouble();
          final lng = (item['longitude'] as num?)?.toDouble();
          if (id is String && courierName is String && fullAddress is String && lat != null && lng != null) {
            parsed.add(CourierOffice(
              id: id,
              courierName: courierName,
              name: item['name'] as String?,
              district: item['district'] as String?,
              fullAddress: fullAddress,
              latitude: lat,
              longitude: lng,
            ));
          }
        }
        if (parsed.isNotEmpty) {
          _offices = parsed;
        }
        if (res['serviceable_districts'] is List) {
          _districts = (res['serviceable_districts'] as List)
              .whereType<String>()
              .map(normalizeDistrict)
              .where((s) => s.isNotEmpty)
              .toList();
        } else {
          _districts = _offices
              .map((o) => normalizeDistrict(o.district))
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();
        }
        _radiusEnabled = res['radius_gate_enabled'] == true;
        _loaded = true;
      }
    } catch (_) {
      // Stay on fallback.
    }
  }

  /// Single gate the screens should call. District first, then radius if the
  /// admin has flipped the flag. Empty district falls back to radius-only so a
  /// geocoder hiccup doesn't lock customers out.
  bool isServiceable(double lat, double lng, String? district, {double radiusM = serviceRadiusM}) {
    final pinDistrict = normalizeDistrict(district);
    if (pinDistrict.isEmpty) {
      return _withinRadius(lat, lng, radiusM);
    }
    if (!_districts.contains(pinDistrict)) return false;
    if (!_radiusEnabled) return true;
    return _withinRadius(lat, lng, radiusM);
  }

  bool _withinRadius(double lat, double lng, double radiusM) {
    for (final o in _offices) {
      if (_distanceMeters(lat, lng, o.latitude, o.longitude) <= radiusM) {
        return true;
      }
    }
    return false;
  }

  // Kept for compatibility with screens that still call isInside without the
  // district. Mirrors the radius-only check.
  bool isInside(double lat, double lng, {double radiusM = serviceRadiusM}) {
    return _withinRadius(lat, lng, radiusM);
  }

  List<RankedOffice> nearby(double lat, double lng, {double radiusM = serviceRadiusM}) {
    final ranked = <RankedOffice>[];
    for (final o in _offices) {
      final d = _distanceMeters(lat, lng, o.latitude, o.longitude);
      if (d <= radiusM) ranked.add(RankedOffice(o, d));
    }
    ranked.sort((a, b) => a.distanceM.compareTo(b.distanceM));
    return ranked;
  }

  CourierOffice? nearest(double lat, double lng) {
    if (_offices.isEmpty) return null;
    CourierOffice best = _offices.first;
    double bestD = _distanceMeters(lat, lng, best.latitude, best.longitude);
    for (final o in _offices.skip(1)) {
      final d = _distanceMeters(lat, lng, o.latitude, o.longitude);
      if (d < bestD) {
        bestD = d;
        best = o;
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
