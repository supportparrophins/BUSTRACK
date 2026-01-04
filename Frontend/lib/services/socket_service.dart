import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/constants.dart';
import '../models/driver_model.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  bool _isAuthenticated = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  // Getters
  bool get isConnected => _socket?.connected ?? false;
  bool get isAuthenticated => _isAuthenticated;

  // Initialize and connect socket
  Future<void> connect(BusModel busData) async {
    if (_isConnecting || isConnected) {
      debugPrint('⚠️ Socket already connecting or connected');
      return;
    }

    _isConnecting = true;
    debugPrint('🔌 Initializing Socket.IO connection...');

    try {
      // Create socket with configuration
      _socket = IO.io(
        AppConstants.socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setReconnectionDelay(3000)
            .setReconnectionDelayMax(10000)
            .setReconnectionAttempts(5)
            .build(),
      );

      _setupSocketListeners(busData);

      // Connect to server
      _socket!.connect();
      debugPrint('🔌 Socket connecting to ${AppConstants.socketUrl}...');
    } catch (e) {
      debugPrint('❌ Socket connection error: $e');
      _isConnecting = false;
      _scheduleReconnect(busData);
    }
  }

  // Setup socket event listeners
  void _setupSocketListeners(BusModel busData) {
    if (_socket == null) return;

    // Connection successful
    _socket!.on('connect', (_) {
      debugPrint('✅ Socket connected: ${_socket!.id}');
      _isConnecting = false;
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();

      // Authenticate immediately after connection
      _authenticate(busData);
    });

    // Authentication successful
    _socket!.on('auth_success', (data) {
      _isAuthenticated = true;
      debugPrint('✅ Authentication successful: $data');
      debugPrint(
          '🔐 Bus ${busData.busId} authenticated on route ${busData.routeId}');
    });

    // Authentication failed
    _socket!.on('auth_failed', (data) {
      _isAuthenticated = false;
      debugPrint('❌ Authentication failed: $data');
      disconnect();
    });

    // Authentication required
    _socket!.on('auth_required', (data) {
      debugPrint('⚠️ Authentication required: $data');
      _authenticate(busData);
    });

    // Duplicate connection detected
    _socket!.on('duplicate_connection', (data) {
      debugPrint('⚠️ Duplicate connection detected: $data');
      debugPrint(
          '🔄 This device was disconnected - another device is now active');
    });

    // Location update acknowledgment
    _socket!.on('location_updated', (data) {
      debugPrint('✅ Location update acknowledged: $data');
    });

    // Disconnect event
    _socket!.on('disconnect', (reason) {
      debugPrint('🔌 Socket disconnected: $reason');
      _isAuthenticated = false;
      _isConnecting = false;

      // Auto-reconnect on unexpected disconnect
      if (reason != 'io client disconnect') {
        _scheduleReconnect(busData);
      }
    });

    // Connection error
    _socket!.on('connect_error', (error) {
      debugPrint('❌ Connection error: $error');
      _isConnecting = false;
      _scheduleReconnect(busData);
    });

    // Connection timeout
    _socket!.on('connect_timeout', (_) {
      debugPrint('⏱️ Connection timeout');
      _isConnecting = false;
      _scheduleReconnect(busData);
    });

    // Reconnection attempt
    _socket!.on('reconnect_attempt', (attempt) {
      debugPrint('🔄 Reconnection attempt: $attempt');
    });

    // Reconnection failed
    _socket!.on('reconnect_failed', (_) {
      debugPrint('❌ Reconnection failed');
      _scheduleReconnect(busData);
    });

    // Error event
    _socket!.on('error', (error) {
      debugPrint('❌ Socket error: $error');
    });
  }

  // Authenticate with server
  void _authenticate(BusModel busData) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('⚠️ Cannot authenticate - socket not connected');
      return;
    }

    debugPrint(
        '🔐 Authenticating bus ${busData.busId} on route ${busData.routeId}...');

    _socket!.emit('authenticate_bus', {
      'bus_id': busData.busId,
      'route_id': busData.routeId,
      'vehicle_number': busData.vehicleNumber,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Emit bus location
  void emitBusLocation({
    required BusModel busData,
    required double lat,
    required double lng,
    required double speed,
    double? heading,
  }) {
    if (!isConnected) {
      debugPrint('⚠️ Cannot emit location - socket not connected');
      return;
    }

    if (!_isAuthenticated) {
      debugPrint('⚠️ Cannot emit location - not authenticated');
      return;
    }

    final locationData = {
      'bus_id': busData.busId,
      'route_id': busData.routeId,
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'heading': heading ?? 0.0,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _socket!.emit('bus_location', locationData);
    debugPrint('📍 Location emitted: Bus ${busData.busId} at ($lat, $lng)');
  }

  // Start trip
  void startTrip(BusModel busData) {
    if (!isConnected || !_isAuthenticated) {
      debugPrint('⚠️ Cannot start trip - not connected or authenticated');
      return;
    }

    _socket!.emit('start_trip', {
      'bus_id': busData.busId,
      'route_id': busData.routeId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    debugPrint('🚀 Trip started for bus ${busData.busId}');
  }

  // End trip
  void endTrip(BusModel busData) {
    if (!isConnected || !_isAuthenticated) {
      debugPrint('⚠️ Cannot end trip - not connected or authenticated');
      return;
    }

    _socket!.emit('end_trip', {
      'bus_id': busData.busId,
      'route_id': busData.routeId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    debugPrint('🛑 Trip ended for bus ${busData.busId}');
  }

  // Schedule reconnection
  void _scheduleReconnect(BusModel busData) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ Max reconnection attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    debugPrint(
        '⏳ Scheduling reconnect attempt $_reconnectAttempts in ${_reconnectDelay.inSeconds}s...');

    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!isConnected && !_isConnecting) {
        debugPrint('🔄 Attempting to reconnect...');
        connect(busData);
      }
    });
  }

  // Disconnect socket
  void disconnect() {
    debugPrint('🔌 Disconnecting socket...');

    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _isAuthenticated = false;
    _isConnecting = false;

    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    debugPrint('✅ Socket disconnected');
  }

  // Dispose (cleanup)
  void dispose() {
    disconnect();
  }
}
