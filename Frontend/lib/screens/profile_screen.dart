import 'package:flutter/material.dart';
import '../models/driver_model.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  BusModel? _busData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final routeId = await AuthService.getRouteId();
    if (routeId != null) {
      final result = await ApiService.getDashboard(routeId);
      if (result['success']) {
        final busData = result['busData'] as BusModel?;

        if (mounted) {
          setState(() {
            _busData = busData;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
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
      body: CustomScrollView(
        slivers: [
          // App Bar with Profile Header
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: 45,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _busData?.routeName ?? 'Route',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _busData?.vehicleNumber ?? 'No Bus Assigned',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _handleLogout,
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _buildBusDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildBusDetails() {
    return SliverList(
      delegate: SliverChildListDelegate([
        _buildDetailCard(
          'Route Information',
          [
            _buildDetailRow(Icons.route, 'Route',
                _busData?.routeName ?? 'N/A'),
            _buildDetailRow(Icons.directions_bus, 'Vehicle Number',
                _busData?.vehicleNumber ?? 'No Bus Assigned'),
            _buildDetailRow(Icons.event_seat, 'Seating Capacity',
                '${_busData?.seatingCapacity ?? 0}'),
          ],
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          'Vehicle Documents',
          [
            _buildDetailRow(
              Icons.shield,
              'Insurance Expiry',
              _busData?.insuranceExpiry != null &&
                      _busData!.insuranceExpiry!.isNotEmpty
                  ? _busData!.insuranceExpiry!
                  : 'Not Available',
            ),
            _buildDetailRow(
              Icons.verified,
              'Fitness Expiry',
              _busData?.fitnessExpiry != null &&
                      _busData!.fitnessExpiry!.isNotEmpty
                  ? _busData!.fitnessExpiry!
                  : 'Not Available',
            ),
          ],
        ),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
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
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
