class AppConstants {
  // API Configuration

  static const String baseUrl =
      'http://192.168.1.108/HOLY_ANGEL_SCHOOL/STUDENT_PORTAL/api';

  // static const String baseUrl =  'https://sjsp.schoolphins.com/student/api';

  static const String routesEndpoint = '/busRoutes';
  static const String dashboardEndpoint = '/busDriverDashboard';

  // SharedPreferences Keys
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyRouteId = 'route_id';
  static const String keyBusData = 'bus_data';

  // Socket Configuration
  static const String socketUrl = 'http://192.168.1.108:3000';

  // static const String socketUrl = 'https://gps.parrophins.com';

  // App Settings
  static const int locationUpdateInterval = 10;
}
