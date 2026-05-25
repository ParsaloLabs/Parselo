import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/theme.dart';
import 'brand_button.dart';

class PickedLocation {
  final double lat;
  final double lng;
  final String fullAddress;
  final String pincode;

  PickedLocation({
    required this.lat,
    required this.lng,
    required this.fullAddress,
    required this.pincode,
  });
}

class MapSelectionDialog extends StatefulWidget {
  final String title;

  const MapSelectionDialog({Key? key, this.title = 'Select Location'}) : super(key: key);

  @override
  State<MapSelectionDialog> createState() => _MapSelectionDialogState();
}

class _MapSelectionDialogState extends State<MapSelectionDialog> {
  late GoogleMapController _mapController;
  LatLng _selectedLatLng = const LatLng(10.5276, 76.2144); // Thrissur Center
  bool _loadingAddress = false;
  String _currentAddress = 'Thrissur, Kerala';
  String _currentPincode = '680001';

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _selectedLatLng = position.target;
    });
  }

  void _onCameraIdle() {
    _resolveAddress();
  }

  Future<void> _resolveAddress() async {
    setState(() {
      _loadingAddress = true;
    });
    
    // Simulate reverse geocoding using LatLng to get pincode & address
    await Future.delayed(const Duration(milliseconds: 600));
    
    // Create a realistic-looking local address in Thrissur based on coordinates
    if (mounted) {
      setState(() {
        _loadingAddress = false;
        // Generate simulated pincodes based on minor lat/lng variations to test logic
        final isEast = _selectedLatLng.longitude > 76.2144;
        _currentPincode = isEast ? '680002' : '680001';
        _currentAddress = 'Street no ${(_selectedLatLng.latitude * 1000 % 20).toStringAsFixed(0)}, Round North, Thrissur, Kerala';
      });
    }
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
