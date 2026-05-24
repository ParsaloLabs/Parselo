import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'agent_service.dart';

class LocationPermissionDenied implements Exception {
  final bool permanently;
  LocationPermissionDenied({this.permanently = false});
}

class LocationServiceDisabled implements Exception {}

class LocationService {
  final AgentService _agent;
  StreamSubscription<Position>? _sub;

  /// Broadcast stream of the latest agent location while tracking is on.
  /// Map widgets subscribe to this instead of starting a parallel geolocator
  /// listener.
  final StreamController<Position> _positions =
      StreamController<Position>.broadcast();
  Position? _last;

  LocationService(this._agent);

  bool get isTracking => _sub != null;
  Stream<Position> get positions => _positions.stream;
  Position? get lastKnown => _last;

  Future<void> start() async {
    if (_sub != null) return;

    final servicesOn = await Geolocator.isLocationServiceEnabled();
    if (!servicesOn) throw LocationServiceDisabled();

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      throw LocationPermissionDenied(permanently: true);
    }
    if (perm == LocationPermission.denied) {
      throw LocationPermissionDenied();
    }

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20, // metres
      ),
    ).listen((pos) {
      _last = pos;
      _positions.add(pos);
      _agent.postLocation(pos.latitude, pos.longitude);
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
