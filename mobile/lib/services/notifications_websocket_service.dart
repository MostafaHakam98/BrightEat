import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../network/ws_connect.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../config/app_config.dart';

class NotificationsWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Function(CollectionOrder)? _onNewOrder;
  Function(Map<String, dynamic>)? _onNotification;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  Timer? _reconnectTimer;
  final SharedPreferences _prefs;
  bool _isConnecting = false;

  NotificationsWebSocketService(this._prefs);

  void connect(
    Function(CollectionOrder) onNewOrder, {
    Function(Map<String, dynamic>)? onNotification,
  }) {
    if (_isConnecting || (_channel != null && _onNewOrder != null)) {
      return; // Already connected or connecting
    }

    _onNewOrder = onNewOrder;
    _onNotification = onNotification;
    _reconnectAttempts = 0;
    _connect();
  }

  void _connect() {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      final token = _prefs.getString('access_token');
      if (token == null) {
        print('⚠️ No access token found for notifications WebSocket authentication');
        _isConnecting = false;
        return;
      }

      // WebSocket routes live at the root (/ws), not under /api
      final wsUrl =
          '${AppConfig.wsBaseUrl}/ws/notifications/?token=${Uri.encodeComponent(token)}';

      // Strip the ?token= query — never log the JWT.
      print('🔌 Connecting to notifications WebSocket: ${wsUrl.split('?').first}');

      _channel = connectWebSocket(wsUrl);

      _subscription = _channel!.stream.listen(
        (message) {
          try {
            print('📥 Raw WebSocket message received: $message');
            final data = jsonDecode(message);
            print('📥 Parsed message type: ${data['type']}');
            
            if (data['type'] == 'new_order' && data['order'] != null) {
              print('📥 Received new_order event via WebSocket');
              print('📥 Order data: ${data['order']}');
              final order = CollectionOrder.fromJson(data['order']);
              print('📥 Parsed order: ${order.code}, Collector: ${order.collector?.id}');
              _onNewOrder?.call(order);
            } else if (data['type'] == 'notification' && data['notification'] != null) {
              // Personal in-app notification (payment_due, order_joined, ...)
              print('📥 Received notification event via WebSocket');
              _onNotification?.call(
                  Map<String, dynamic>.from(data['notification'] as Map));
            } else if (data['type'] == 'pong') {
              // Heartbeat response
              print('💓 Notifications WebSocket heartbeat received');
            } else {
              print('⚠️ Unknown message type: ${data['type']}');
            }
          } catch (e) {
            print('❌ Error parsing notifications WebSocket message: $e');
            print('❌ Message was: $message');
          }
        },
        onError: (error) {
          print('❌ Notifications WebSocket error: $error');
          // Don't reconnect on server errors (500) - likely server-side issue
          if (error.toString().contains('500') || error.toString().contains('HTTP status code: 500')) {
            print('⚠️ Server returned 500 error - Notifications WebSocket endpoint may not be available');
            print('⚠️ Disabling WebSocket reconnection for this session');
            _reconnectAttempts = _maxReconnectAttempts; // Prevent reconnection attempts
          }
          _isConnecting = false;
          _handleDisconnect();
        },
        onDone: () {
          print('🔌 Notifications WebSocket connection closed');
          _isConnecting = false;
          _handleDisconnect();
        },
        cancelOnError: false,
      );

      // Send ping every 30 seconds to keep connection alive
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_channel != null) {
          try {
            _channel!.sink.add(jsonEncode({'type': 'ping'}));
          } catch (e) {
            print('❌ Error sending notifications ping: $e');
          }
        }
      });

      print('✅ Notifications WebSocket connected');
      _isConnecting = false;
    } catch (e) {
      print('❌ Error connecting notifications WebSocket: $e');
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;

    // Attempt to reconnect if we haven't exceeded max attempts
    if (_reconnectAttempts < _maxReconnectAttempts && _onNewOrder != null) {
      _reconnectAttempts++;
      print('🔄 Reconnecting notifications WebSocket in ${_reconnectDelay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
      
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(_reconnectDelay, () {
        _connect();
      });
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ Max reconnection attempts reached for notifications WebSocket');
    }
  }

  void disconnect() {
    print('🔌 Disconnecting notifications WebSocket');
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _onNewOrder = null;
    _onNotification = null;
    _reconnectAttempts = 0;
    _isConnecting = false;
  }

  bool get isConnected => _channel != null;
}

