import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../state/providers.dart';

/// Embedded Google Map showing pickup + drop markers and the live agent
/// position. Below the map sit two "Navigate" buttons that hand off to the
/// system maps app via a universal Google Maps URL.
class JobMap extends ConsumerStatefulWidget {
  final LatLng? pickup;
  final String? pickupLabel;
  final LatLng? drop;
  final String? dropLabel;
  final bool dropIsActive;
  final List<LatLng>? routePoints;
  final String? distanceText;
  final String? durationText;
  final bool routeLoading;
  final String? routeError;

  const JobMap({
    super.key,
    this.pickup,
    this.pickupLabel,
    this.drop,
    this.dropLabel,
    this.dropIsActive = false,
    this.routePoints,
    this.distanceText,
    this.durationText,
    this.routeLoading = false,
    this.routeError,
  });

  @override
  ConsumerState<JobMap> createState() => _JobMapState();
}

class _JobMapState extends ConsumerState<JobMap> {
  GoogleMapController? _controller;
  bool _movedToInitial = false;

  LatLng? get _initialCenter {
    final active = widget.dropIsActive ? widget.drop : widget.pickup;
    return active ?? widget.pickup ?? widget.drop;
  }

  Set<Marker> _markers(LatLng? agent) {
    final out = <Marker>{};
    if (widget.pickup != null) {
      out.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickup!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: widget.pickupLabel ?? 'Pickup'),
        ),
      );
    }
    if (widget.drop != null) {
      out.add(
        Marker(
          markerId: const MarkerId('drop'),
          position: widget.drop!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: widget.dropLabel ?? 'Drop'),
        ),
      );
    }
    if (agent != null) {
      out.add(
        Marker(
          markerId: const MarkerId('agent'),
          position: agent,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You'),
        ),
      );
    }
    return out;
  }

  Set<Polyline> _polylines() {
    final r = widget.routePoints;
    if (r == null || r.length < 2) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: r,
        width: 5,
        color: BrandColors.brand,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  void _fitBounds(LatLng? agent) {
    final pts = <LatLng>[
      ?widget.pickup,
      ?widget.drop,
      ?agent,
    ];
    if (pts.isEmpty || _controller == null) return;
    if (pts.length == 1) {
      _controller!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 14));
      return;
    }
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        56,
      ),
    );
  }

  Future<void> _openNav(LatLng target) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${target.latitude},${target.longitude}'
      '&travelmode=driving',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final center = _initialCenter;
    final agentAsync = ref.watch(agentPositionProvider);
    final agent = agentAsync.valueOrNull;
    final agentLatLng =
        agent == null ? null : LatLng(agent.latitude, agent.longitude);

    if (center == null) {
      return _NavOnlyFallback(
        pickup: widget.pickup,
        drop: widget.drop,
        onTap: _openNav,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: center, zoom: 14),
                  markers: _markers(agentLatLng),
                  polylines: _polylines(),
                  myLocationButtonEnabled: false,
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  onMapCreated: (c) {
                    _controller = c;
                    if (!_movedToInitial) {
                      _movedToInitial = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _fitBounds(agentLatLng);
                      });
                    }
                  },
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: _RouteChip(
                    loading: widget.routeLoading,
                    distanceText: widget.distanceText,
                    durationText: widget.durationText,
                    error: widget.routeError,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: BrandColors.slate200)),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: _NavButton(
                    label: 'Pickup',
                    active: !widget.dropIsActive,
                    enabled: widget.pickup != null,
                    onTap: widget.pickup == null
                        ? null
                        : () => _openNav(widget.pickup!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NavButton(
                    label: 'Drop',
                    active: widget.dropIsActive,
                    enabled: widget.drop != null,
                    onTap: widget.drop == null
                        ? null
                        : () => _openNav(widget.drop!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;
  const _NavButton({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? BrandColors.brand : BrandColors.slate100;
    final fg = active ? Colors.white : BrandColors.slate700;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new, color: fg, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Open $label in Google Maps',
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// When neither pickup nor drop has coordinates, hide the map entirely and
/// just show the two nav buttons (disabled if no coords).
class _NavOnlyFallback extends StatelessWidget {
  final LatLng? pickup;
  final LatLng? drop;
  final Future<void> Function(LatLng) onTap;
  const _NavOnlyFallback({
    required this.pickup,
    required this.drop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (pickup == null && drop == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.slate200),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: _NavButton(
              label: 'Pickup',
              active: true,
              enabled: pickup != null,
              onTap: pickup == null ? null : () => onTap(pickup!),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NavButton(
              label: 'Drop',
              active: false,
              enabled: drop != null,
              onTap: drop == null ? null : () => onTap(drop!),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact pill anchored to the top of the map with distance + ETA, a
/// loading state, or a short error label. Hidden entirely when nothing is
/// available to show (e.g. before the first fetch with no error).
class _RouteChip extends StatelessWidget {
  final bool loading;
  final String? distanceText;
  final String? durationText;
  final String? error;
  const _RouteChip({
    required this.loading,
    required this.distanceText,
    required this.durationText,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final hasRoute =
        (distanceText?.isNotEmpty ?? false) && (durationText?.isNotEmpty ?? false);
    if (!loading && !hasRoute && (error?.isEmpty ?? true)) {
      return const SizedBox.shrink();
    }

    final Widget content;
    if (loading) {
      content = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: BrandColors.brand,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Finding route…',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: BrandColors.slate700,
            ),
          ),
        ],
      );
    } else if (hasRoute) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.alt_route, size: 14, color: BrandColors.brand),
          const SizedBox(width: 6),
          Text(
            durationText!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: BrandColors.slate800,
            ),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 12, color: BrandColors.slate200),
          const SizedBox(width: 6),
          Text(
            distanceText!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: BrandColors.slate600,
            ),
          ),
        ],
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 14, color: BrandColors.rose600),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              error ?? 'Route unavailable',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: BrandColors.rose600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BrandColors.slate200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}

/// Hide the embedded map if the user is on the geolocator default position
/// (lat 0 / lng 0 sentinel). Helpful for tests + emulators without GPS fix.
bool isNullIsland(Position p) =>
    p.latitude.abs() < 0.001 && p.longitude.abs() < 0.001;
