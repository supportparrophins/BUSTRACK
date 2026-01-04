import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/driver_model.dart';
import '../models/route_model.dart';

class ApiService {
  static Future<Map<String, dynamic>> getRoutes() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.routesEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({}),
      );

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server returned empty response.',
        };
      }

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        List<RouteModel> routes = [];
        if (data['routes'] != null) {
          routes = (data['routes'] as List)
              .map((route) => RouteModel.fromJson(route))
              .toList();
        }

        return {
          'success': true,
          'routes': routes,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'No routes available',
        };
      }
    } catch (e) {
      debugPrint('Error fetching routes: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection.',
      };
    }
  }

  static Future<Map<String, dynamic>> getDashboard(int routeId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.dashboardEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'route_id': routeId}),
      );

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server returned empty response.',
        };
      }

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        final busModel = BusModel.fromJson(data['bus_details']);

        return {
          'success': true,
          'busData': busModel,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to load dashboard',
        };
      }
    } catch (e) {
      debugPrint('Dashboard error: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection.',
      };
    }
  }

  static Future<Map<String, dynamic>> saveTripData({
    required int busId,
    required int routeId,
    required List<Map<String, double>> routePoints,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/saveTripRoute'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'bus_id': busId,
          'route_id': routeId,
          'route_points': routePoints,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Server returned empty response.',
        };
      }

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Trip data saved successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to save trip data',
        };
      }
    } catch (e) {
      debugPrint('Error saving trip data: $e');
      return {
        'success': false,
        'message': 'Network error. Please check your connection.',
      };
    }
  }
}
