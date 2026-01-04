class RouteModel {
  final int routeId;
  final String routeName;
  final String? vehicleNumber;

  RouteModel({
    required this.routeId,
    required this.routeName,
    this.vehicleNumber,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      routeId: json['route_id'] ?? 0,
      routeName: json['route_name'] ?? '',
      vehicleNumber: json['vehicle_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'route_name': routeName,
      'vehicle_number': vehicleNumber,
    };
  }

  // Display text for dropdown
  String get displayText {
    if (vehicleNumber != null && vehicleNumber!.isNotEmpty) {
      return '$routeName - $vehicleNumber';
    }
    return routeName;
  }
}
