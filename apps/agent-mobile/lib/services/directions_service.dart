import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/env.dart';

class DirectionsResult {
  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;
  final String distanceText;
  final String durationText;

  const DirectionsResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceText,
    required this.durationText,
  });
}

class DirectionsUnavailable implements Exception {
  final String reason;
  DirectionsUnavailable(this.reason);
  @override
  String toString() => 'DirectionsUnavailable: $reason';
}

/// Thin wrapper around the Google Directions API.
/// Returns a decoded polyline plus distance/ETA text suitable for
/// rendering as a chip on the embedded map.
class DirectionsService {
  final Dio _dio;

  DirectionsService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  Future<DirectionsResult> fetchRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final key = Env.googleApiKey;
    if (key.isEmpty) {
      throw DirectionsUnavailable('missing_api_key');
    }
    final res = await _dio.get<Map<String, dynamic>>(
      'https://maps.googleapis.com/maps/api/directions/json',
      queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': key,
      },
    );
    final body = res.data ?? const {};
    final status = body['status'] as String? ?? 'UNKNOWN';
    if (status != 'OK') {
      throw DirectionsUnavailable(status.toLowerCase());
    }
    final routes = body['routes'] as List? ?? const [];
    if (routes.isEmpty) throw DirectionsUnavailable('no_routes');
    final route = routes.first as Map<String, dynamic>;
    final overview = route['overview_polyline'] as Map<String, dynamic>?;
    final encoded = overview?['points'] as String? ?? '';
    if (encoded.isEmpty) throw DirectionsUnavailable('empty_polyline');
    final legs = route['legs'] as List? ?? const [];
    if (legs.isEmpty) throw DirectionsUnavailable('no_legs');
    final leg = legs.first as Map<String, dynamic>;
    final distance = leg['distance'] as Map<String, dynamic>? ?? const {};
    final duration = leg['duration'] as Map<String, dynamic>? ?? const {};
    return DirectionsResult(
      points: _decodePolyline(encoded),
      distanceMeters: (distance['value'] as num?)?.toInt() ?? 0,
      durationSeconds: (duration['value'] as num?)?.toInt() ?? 0,
      distanceText: distance['text'] as String? ?? '',
      durationText: duration['text'] as String? ?? '',
    );
  }
}

/// Decode Google's encoded polyline algorithm format:
/// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
List<LatLng> _decodePolyline(String encoded) {
  final out = <LatLng>[];
  int index = 0;
  int lat = 0;
  int lng = 0;
  while (index < encoded.length) {
    int result = 0;
    int shift = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dLat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
    lat += dLat;

    result = 0;
    shift = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dLng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
    lng += dLng;

    out.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return out;
}
