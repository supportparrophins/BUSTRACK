class RouteModel {
  final int routeId;
  final String routeName;
  final String? vehicleNumber;
  final bool isLocked; // New field to track if route is locked

  RouteModel({
    required this.routeId,
    required this.routeName,
    this.vehicleNumber,
    this.isLocked = false, // Default to not locked
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      routeId: json['route_id'] ?? 0,
      routeName: json['route_name'] ?? '',
      vehicleNumber: json['vehicle_number'],
      isLocked: json['is_locked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'route_name': routeName,
      'vehicle_number': vehicleNumber,
      'is_locked': isLocked,
    };
  }

  // Display text for dropdown
  String get displayText {
    String text = '';
    if (vehicleNumber != null && vehicleNumber!.isNotEmpty) {
      text = '$routeName - $vehicleNumber';
    } else {
      text = routeName;
    }
    
    if (isLocked) {
      text += ' (Already Tracking)';
    }
    
    return text;
  }
}
