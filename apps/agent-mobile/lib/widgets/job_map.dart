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

  const JobMap({
    super.key,
    this.pickup,
    this.pickupLabel,
    this.drop,
    this.dropLabel,
    this.dropIsActive = false,
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
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 14),
              markers: _markers(agentLatLng),
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
                Icon(Icons.directions_outlined, color: fg, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Navigate to $label',
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

/// Hide the embedded map if the user is on the geolocator default position
/// (lat 0 / lng 0 sentinel). Helpful for tests + emulators without GPS fix.
bool isNullIsland(Position p) =>
    p.latitude.abs() < 0.001 && p.longitude.abs() < 0.001;
