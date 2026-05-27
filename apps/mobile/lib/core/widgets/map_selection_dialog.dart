import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/theme.dart';
import 'brand_button.dart';

class PickedLocation {
  final double lat;
  final double lng;
  final String fullAddress;
  final String pincode;
  final String district;

  PickedLocation({
    required this.lat,
    required this.lng,
    required this.fullAddress,
    required this.pincode,
    this.district = '',
  });
}

class MapSelectionDialog extends StatefulWidget {
  final String title;
  final PickedLocation? initialLocation;

  const MapSelectionDialog({
    Key? key,
    this.title = 'Select Location',
    this.initialLocation,
  }) : super(key: key);

  @override
  State<MapSelectionDialog> createState() => _MapSelectionDialogState();
}

class _MapSelectionDialogState extends State<MapSelectionDialog> {
  late GoogleMapController _mapController;
  late LatLng _selectedLatLng;
  bool _loadingAddress = false;
  late String _currentAddress;
  late String _currentPincode;
  late String _currentDistrict;
  int _resolveSeq = 0;

  @override
  void initState() {
    super.initState();
    final init = widget.initialLocation;
    if (init != null) {
      _selectedLatLng = LatLng(init.lat, init.lng);
      _currentAddress = init.fullAddress;
      _currentPincode = init.pincode;
      _currentDistrict = init.district;
    } else {
      _selectedLatLng = const LatLng(10.5276, 76.2144); // Thrissur Center
      _currentAddress = 'Thrissur, Kerala';
      _currentPincode = '680001';
      _currentDistrict = 'Thrissur';
    }
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _selectedLatLng = position.target;
    });
  }

  void _onCameraIdle() {
    _resolveAddress();
  }

  // Real reverse geocoding via platform geocoder (iOS CLGeocoder /
  // Android Geocoder — no API key needed). subAdministrativeArea is the
  // district in India. We sequence-guard so a stale callback can't clobber
  // the result of a newer pin drop.
  Future<void> _resolveAddress() async {
    final mySeq = ++_resolveSeq;
    setState(() {
      _loadingAddress = true;
    });
    try {
      final placemarks = await placemarkFromCoordinates(
        _selectedLatLng.latitude,
        _selectedLatLng.longitude,
      );
      if (!mounted || mySeq != _resolveSeq) return;
      if (placemarks.isEmpty) {
        setState(() {
          _loadingAddress = false;
        });
        return;
      }
      final p = placemarks.first;
      final parts = <String>[
        if ((p.name ?? '').isNotEmpty) p.name!,
        if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
        if ((p.locality ?? '').isNotEmpty) p.locality!,
        if ((p.subAdministrativeArea ?? '').isNotEmpty) p.subAdministrativeArea!,
        if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
      ];
      setState(() {
        _loadingAddress = false;
        _currentAddress = parts.join(', ');
        _currentPincode = (p.postalCode ?? '').trim();
        _currentDistrict = (p.subAdministrativeArea ?? '').trim();
      });
    } catch (_) {
      if (!mounted || mySeq != _resolveSeq) return;
      setState(() {
        _loadingAddress = false;
      });
    }
  }

  final TextEditingController _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _searching = true;
    });
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final latLng = LatLng(loc.latitude, loc.longitude);
        _selectedLatLng = latLng;
        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 16),
        );
        _resolveAddress();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location not found. Try a different query.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find that location. Please try adding more details.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Future<void> _determinePosition() async {
    if (widget.initialLocation != null) return;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final latLng = LatLng(position.latitude, position.longitude);
      _selectedLatLng = latLng;
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(latLng, 16),
      );
      _resolveAddress();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  )
                ],
              ),
            ),
            
            // Map Canvas
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _selectedLatLng,
                      zoom: 15,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _resolveAddress();
                      _determinePosition();
                    },
                    onCameraMove: _onCameraMove,
                    onCameraIdle: _onCameraIdle,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                  
                  // Central Pin Overlay
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 36), // Offset for pin point
                      child: Icon(
                        Icons.location_on_rounded,
                        color: AppColors.brand,
                        size: 44,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                    ),
                  ),
                  // Search Bar Overlay
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Card(
                      elevation: 4,
                      shadowColor: Colors.black.withOpacity(0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: AppColors.brand, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                textInputAction: TextInputAction.search,
                                onSubmitted: _searchAddress,
                                onChanged: (val) {
                                  setState(() {});
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Search address or landmark...',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                  filled: false,
                                ),
                                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                              ),
                            ),
                            if (_searching)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
                              )
                            else if (_searchCtrl.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _searchCtrl.clear();
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom Address Details
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_searching_rounded, color: AppColors.brand.withOpacity(0.8), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _loadingAddress 
                          ? const Text(
                              'Resolving address...',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontStyle: FontStyle.italic),
                            )
                          : Text(
                              _currentAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                      ),
                    ],
                  ),
                  if (!_loadingAddress) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Text(
                        'Pincode: $_currentPincode',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    )
                  ],
                  const SizedBox(height: 16),
                  BrandButton(
                    text: 'Confirm Location',
                    onPressed: _loadingAddress 
                      ? null 
                      : () {
                          Navigator.of(context).pop(
                            PickedLocation(
                              lat: _selectedLatLng.latitude,
                              lng: _selectedLatLng.longitude,
                              fullAddress: _currentAddress,
                              pincode: _currentPincode,
                              district: _currentDistrict,
                            ),
                          );
                        },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
