import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/route_model.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  List<RouteModel> _routes = [];
  RouteModel? _selectedRoute;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.getRoutes();

      if (result['success']) {
        setState(() {
          _routes = result['routes'] as List<RouteModel>;
          _isLoading = false;
        });
      } else {
        _showMessage(result['message']);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showMessage('Failed to load routes: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRouteSelection() async {
    if (_selectedRoute == null) {
      _showMessage('Please select a route');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ApiService.getDashboard(_selectedRoute!.routeId);

      if (!result['success']) {
        _showMessage(result['message']);
        setState(() => _isSubmitting = false);
        return;
      }

      await AuthService.saveRouteData(
        _selectedRoute!.routeId,
        result['busData'],
      );

      // Request location permissions
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage('Location permission is required to track the bus');
        setState(() => _isSubmitting = false);
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Get initial position
        try {
          await Geolocator.getCurrentPosition();
        } catch (e) {
          debugPrint('Could not get initial position: $e');
        }

        // Start background service
        await Future.delayed(const Duration(milliseconds: 500));
        final service = FlutterBackgroundService();

        if (await service.isRunning()) {
          service.invoke('stop');
          await Future.delayed(const Duration(milliseconds: 500));
        }

        service.startService();

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        _showMessage('Location permission is required');
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      _showMessage('Failed to start: ${e.toString()}');
      setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade700, Colors.blue.shade400],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_bus,
                      size: 60,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  const Text(
                    'Bus Driver App',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Track & Manage Your Route',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Route Selection Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Select Route',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose the route you want to manage',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Route Dropdown
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(),
                          )
                        else if (_routes.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No routes available',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadRoutes,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<RouteModel>(
                                value: _selectedRoute,
                                isExpanded: true,
                                hint: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Icon(Icons.route, color: Colors.grey),
                                      SizedBox(width: 12),
                                      Text(
                                        'Select a route',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                items: _routes.map((route) {
                                  return DropdownMenuItem<RouteModel>(
                                    value: route,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Text(route.displayText),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (RouteModel? value) {
                                  setState(() {
                                    _selectedRoute = value;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),

                        // Continue Button
                        ElevatedButton(
                          onPressed: (_isLoading ||
                                  _isSubmitting ||
                                  _selectedRoute == null)
                              ? null
                              : _handleRouteSelection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Start',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Footer
                  const Text(
                    'Select your route and press Start\nto begin location tracking',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
