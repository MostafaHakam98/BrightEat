import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart';
import '../config/app_config.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  int? _currentOrderId;
  Function(CollectionOrder)? _onOrderUpdate;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  Timer? _reconnectTimer;
  final SharedPreferences _prefs;

  WebSocketService(this._prefs);

  void connect(int orderId, Function(CollectionOrder) onOrderUpdate) {
    // If already connected to this order, don't reconnect
    if (_channel != null && _currentOrderId == orderId) {
      return;
    }

    // Disconnect from previous order if different
    if (_currentOrderId != null && _currentOrderId != orderId) {
      disconnect();
    }

    _currentOrderId = orderId;
    _onOrderUpdate = onOrderUpdate;
    _reconnectAttempts = 0;

    _connect();
  }

  void _connect() {
    try {
      final token = _prefs.getString('access_token');
      if (token == null) {
        print('⚠️ No access token found for WebSocket authentication');
        return;
      }

      // WebSocket routes live at the root (/ws), not under /api
      final wsUrl =
          '${AppConfig.wsBaseUrl}/ws/orders/${_currentOrderId}/?token=${Uri.encodeComponent(token)}';

      // Strip the ?token= query — never log the JWT.
      print('🔌 Connecting to WebSocket: ${wsUrl.split('?').first}');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'order_update' && data['order'] != null) {
              print('📥 Received order update via WebSocket');
              final order = CollectionOrder.fromJson(data['order']);
              _onOrderUpdate?.call(order);
            } else if (data['type'] == 'pong') {
              // Heartbeat response
              print('💓 WebSocket heartbeat received');
            }
          } catch (e) {
            print('❌ Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          // Don't reconnect on server errors (500) - likely server-side issue
          if (error.toString().contains('500') || error.toString().contains('HTTP status code: 500')) {
            print('⚠️ Server returned 500 error - WebSocket endpoint may not be available');
            print('⚠️ Disabling WebSocket reconnection for this session');
            _reconnectAttempts = _maxReconnectAttempts; // Prevent reconnection attempts
          }
          _handleDisconnect();
        },
        onDone: () {
          print('🔌 WebSocket connection closed');
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
            print('❌ Error sending ping: $e');
          }
        }
      });

      print('✅ WebSocket connected for order: $_currentOrderId');
    } catch (e) {
      print('❌ Error connecting WebSocket: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;

    // Attempt to reconnect if we haven't exceeded max attempts
    if (_reconnectAttempts < _maxReconnectAttempts && _currentOrderId != null && _onOrderUpdate != null) {
      _reconnectAttempts++;
      print('🔄 Reconnecting WebSocket in ${_reconnectDelay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
      
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(_reconnectDelay, () {
        _connect();
      });
    } else if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ Max reconnection attempts reached');
    }
  }

  void disconnect() {
    print('🔌 Disconnecting WebSocket');
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _currentOrderId = null;
    _onOrderUpdate = null;
    _reconnectAttempts = 0;
  }

  bool get isConnected => _channel != null;
}

