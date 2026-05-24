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

  LocationService(this._agent);

  bool get isTracking => _sub != null;

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
      _agent.postLocation(pos.latitude, pos.longitude);
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
