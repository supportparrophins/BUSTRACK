import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/driver_model.dart';

class AuthService {
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;
  }

  static Future<int?> getRouteId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.keyRouteId);
  }

  static Future<BusModel?> getBusData() async {
    final prefs = await SharedPreferences.getInstance();
    final busJson = prefs.getString(AppConstants.keyBusData);
    if (busJson != null) {
      return BusModel.fromJson(json.decode(busJson));
    }
    return null;
  }

  static Future<void> saveRouteData(int routeId, BusModel busData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsLoggedIn, true);
    await prefs.setInt(AppConstants.keyRouteId, routeId);
    await prefs.setString(AppConstants.keyBusData, json.encode(busData.toJson()));
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
