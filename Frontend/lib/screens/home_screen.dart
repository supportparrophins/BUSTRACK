import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:lottie/lottie.dart' as lottie;
import '../models/driver_model.dart';
import '../services/auth_service.dart';

import 'profile_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BusModel? _busData;
  Position? _currentPosition;
  final MapController _mapController = MapController();
  bool _isLoading = true;
  final List<LatLng> _routePoints = [];
  bool _isTripActive = true;
  double _currentHeading = 0.0;
  bool _followLocation = true; // Auto-follow user location
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startLocationUpdates();
  }

  Future<void> _loadData() async {
    final busData = await AuthService.getBusData();

    if (mounted) {
      setState(() {
        _busData = busData;
        // Only set loading to false after we have location
      });
    }
  }

  Future<void> _startLocationUpdates() async {
    try {
      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied');
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Get initial position
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        debugPrint(
            'Initial position: ${position.latitude}, ${position.longitude}');

        if (mounted) {
          setState(() {
            _currentPosition = position;
            _isLoading = false;
            if (_isTripActive) {
              _routePoints.add(LatLng(position.latitude, position.longitude));
            }
          });

          // Wait a frame for map to be ready, then center
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              _mapController.move(
                LatLng(position.latitude, position.longitude),
                16,
              );
              _mapReady = true;
              debugPrint('🗺️ Map initialized and centered');
            } catch (e) {
              debugPrint('⚠️ Map move error: $e');
            }
          });
        }

        // Start listening to position updates
        const locationSettings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0, // Get all updates
        );

        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            debugPrint(
                '🔔 NEW Position received: ${position.latitude}, ${position.longitude}, Speed: ${position.speed}');

            if (!mounted || !_isTripActive) {
              debugPrint(
                  '⚠️ Not updating - mounted: $mounted, tripActive: $_isTripActive');
              return;
            }

            final newPoint = LatLng(position.latitude, position.longitude);

            setState(() {
              // Calculate heading
              if (_currentPosition != null) {
                final bearing = Geolocator.bearingBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  position.latitude,
                  position.longitude,
                );
                if (bearing.abs() > 1) {
                  _currentHeading = bearing;
                  debugPrint('📐 Heading updated: $_currentHeading');
                }
              }

              _currentPosition = position;
              _routePoints.add(newPoint);

              debugPrint(
                  '✅ Position: ${position.latitude}, ${position.longitude}');
              debugPrint('✅ Route points: ${_routePoints.length}');
            });

            // Auto-center map after setState completes
            if (_followLocation && _mapReady) {
              Future.microtask(() {
                try {
                  _mapController.move(
                    newPoint,
                    _mapController.camera.zoom,
                  );
                  debugPrint(
                      '🗺️ Map centered on: ${position.latitude}, ${position.longitude}');
                } catch (e) {
                  debugPrint('⚠️ Map move error: $e');
                }
              });
            }
          },
          onError: (error) {
            debugPrint('❌ Position stream error: $error');
          },
        );
      }
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
    }
  }

  Future<void> _endTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Trip'),
        content: const Text(
          'Are you sure you want to end the trip?\n\nThis will stop location tracking, save your trip history, and you will be logged out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isTripActive = false);

      // Stop background service - this will automatically emit end_trip
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('stop');
      }

      // Wait a moment for the end_trip event to be sent
      await Future.delayed(const Duration(seconds: 1));

      // Clear route data and logout
      await AuthService.logout();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bus Tracker',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (_busData != null)
              Text(
                _busData!.routeName,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade500],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(
                      0, 0), // Will be updated when location is available
              initialZoom: 16,
              minZoom: 10,
              maxZoom: 19,
              onMapEvent: (event) {
                // Disable auto-follow when user manually interacts with map
                if (event.source == MapEventSource.dragStart ||
                    event.source == MapEventSource.onDrag ||
                    event.source == MapEventSource.doubleTap) {
                  setState(() {
                    _followLocation = false;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bus_driver_app',
              ),
              // Polyline showing route traveled
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue.shade600,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              // Bus marker at current position
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 60,
                      height: 60,
                      point: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      child: Transform.rotate(
                        angle: _currentHeading *
                            3.14159 /
                            180, // Convert to radians
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // Main marker
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.blue.shade700,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.navigation,
                                color: Colors.blue.shade700,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Location status indicator
          if (_currentPosition == null)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(Colors.orange.shade700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Getting location...',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Zoom Controls
          Positioned(
            top: 100,
            right: 16,
            child: Column(
              children: [
                // Zoom In Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                        _mapController.camera.center,
                        currentZoom + 1,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Zoom Out Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                        _mapController.camera.center,
                        currentZoom - 1,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // My Location Button
          Positioned(
            bottom: 240,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.my_location, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _followLocation = true; // Re-enable auto-follow
                  });
                  if (_currentPosition != null) {
                    _mapController.move(
                      LatLng(_currentPosition!.latitude,
                          _currentPosition!.longitude),
                      16,
                    );
                  }
                },
              ),
            ),
          ),

          // End Trip Button - Centered above bottom card
          Positioned(
            bottom: 180,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  onTap: _endTrip,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.shade600,
                          Colors.red.shade700,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stop_circle,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'End Trip',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Info Card at Bottom
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: lottie.Lottie.asset(
                          'assets/lottie/Moving Bus.json',
                          width: 35,
                          height: 35,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.directions_bus,
                              color: Colors.blue.shade700,
                              size: 30,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _busData?.vehicleNumber ?? 'No Bus Assigned',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _busData?.routeName ?? 'Route N/A',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color: Colors.green.shade700,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_currentPosition != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Center(
                      child: _buildInfoItem(
                        Icons.speed,
                        'Speed',
                        '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
