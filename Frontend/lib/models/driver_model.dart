class BusModel {
  final int? busId;
  final int routeId;
  final String? vehicleNumber;
  final int seatingCapacity;
  final String routeName;
  final String? insuranceExpiry;
  final String? fitnessExpiry;

  BusModel({
    this.busId,
    required this.routeId,
    this.vehicleNumber,
    required this.seatingCapacity,
    required this.routeName,
    this.insuranceExpiry,
    this.fitnessExpiry,
  });

  factory BusModel.fromJson(Map<String, dynamic> json) {
    return BusModel(
      busId: json['bus_id'],
      routeId: json['route_id'] ?? 0,
      vehicleNumber: json['vehicle_number'],
      seatingCapacity: json['seating_capacity'] ?? 0,
      routeName: json['route_name'] ?? '',
      insuranceExpiry: json['insurance_expiry'],
      fitnessExpiry: json['fitness_expiry'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bus_id': busId,
      'route_id': routeId,
      'vehicle_number': vehicleNumber,
      'seating_capacity': seatingCapacity,
      'route_name': routeName,
      'insurance_expiry': insuranceExpiry,
      'fitness_expiry': fitnessExpiry,
    };
  }

  bool get hasBusAssigned => busId != null && vehicleNumber != null;
}
