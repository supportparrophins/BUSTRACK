import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'config/constants.dart';

// Background service entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "Bus Tracker",
      content: "Starting location tracking...",
    );

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Bus Tracker",
          content: "Location permission required",
        );
      }
      return;
    }
  } catch (e) {
    debugPrint('Error checking permissions: $e');
    return;
  }

  final driver = await AuthService.getBusData();
  if (driver == null) {
    service.stopSelf();
    return;
  }

  // Initialize socket connection
  IO.Socket socket = IO.io(
    AppConstants.socketUrl,
    IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .enableReconnection()
        .setReconnectionAttempts(999999)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .setRandomizationFactor(0.5)
        .setTimeout(20000)
        .build(),
  );

  Position? lastPosition;
  StreamSubscription<Position>? positionStream;
  Timer? sendTimer;
  bool isConnected = false;

  socket.onConnect((_) {
    isConnected = true;
    debugPrint('✅ Socket connected successfully');
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Bus Tracker Active",
        content: "Connected - ${driver.vehicleNumber ?? 'Tracking'}",
      );
    }
  });

  socket.onDisconnect((_) {
    isConnected = false;
    debugPrint('❌ Socket disconnected');
  });

  // Listen for trip_ended confirmation
  socket.on('trip_ended', (data) {
    debugPrint('✅ Trip ended confirmation received: $data');
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Trip Completed",
        content: "Trip saved successfully",
      );
    }
  });

  socket.connect();

  // Start listening to position stream
  try {
    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        forceLocationManager: false,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        lastPosition = position;
      },
      onError: (error) {
        debugPrint('Position error: $error');
      },
    );
  } catch (e) {
    debugPrint('Error starting location: $e');
  }

  // Send location updates
  sendTimer = Timer.periodic(
      Duration(seconds: AppConstants.locationUpdateInterval), (timer) async {
    try {
      if (lastPosition == null) {
        try {
          lastPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(const Duration(seconds: 5));
        } catch (e) {
          return;
        }
      }

      if (lastPosition != null && isConnected) {
        // Convert speed from m/s to km/h
        final speedKmh =
            (lastPosition!.speed * 3.6).clamp(0.0, double.infinity);

        final locationData = {
          "bus_id": driver.busId,
          "route_id": driver.routeId,
          "lat": lastPosition!.latitude,
          "lng": lastPosition!.longitude,
          "speed":
              double.parse(speedKmh.toStringAsFixed(1)), // Send speed in km/h
        };

        socket.emit("bus_location", locationData);
        debugPrint(
            '📍 Location sent: Bus ${driver.busId}, Lat: ${lastPosition!.latitude}, Lng: ${lastPosition!.longitude}, Speed: $speedKmh km/h');

        if (service is AndroidServiceInstance) {
          final speedText = speedKmh > 0
              ? '${speedKmh.toStringAsFixed(1)} km/h'
              : 'Stationary';
          service.setForegroundNotificationInfo(
            title: "Bus Tracker Active",
            content: "$speedText - ${driver.vehicleNumber}",
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending location: $e');
    }
  });

  service.on('stop').listen((event) {
    // Emit end_trip before stopping
    if (isConnected && driver.busId != null) {
      debugPrint('🛑 Emitting end_trip for bus_id: ${driver.busId}');
      socket.emit('end_trip', {'bus_id': driver.busId});
      // Give socket time to send the event
      Future.delayed(const Duration(milliseconds: 500), () {
        sendTimer?.cancel();
        positionStream?.cancel();
        socket.disconnect();
        socket.dispose();
        service.stopSelf();
      });
    } else {
      sendTimer?.cancel();
      positionStream?.cancel();
      socket.disconnect();
      socket.dispose();
      service.stopSelf();
    }
  });
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'bus_tracker_channel',
      initialNotificationTitle: 'Bus Tracker',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();

  // Enable wake lock
  await WakelockPlus.enable();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Driver App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    final isLoggedIn = await AuthService.isLoggedIn();
    final routeId = await AuthService.getRouteId();
    final busData = await AuthService.getBusData();

    print('🔍 Splash: isLoggedIn = $isLoggedIn');
    print('🔍 Splash: routeId = $routeId');
    print('🔍 Splash: busData = ${busData?.toJson()}');

    if (mounted) {
      if (isLoggedIn && routeId != null && busData != null) {
        print('✅ Splash: Navigating to HomeScreen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        print('✅ Splash: Navigating to LoginScreen');
        // Clear any partial data
        await AuthService.logout();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_bus,
                size: 100,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              Text(
                'Bus Driver App',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
