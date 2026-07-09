import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/notifications_websocket_service.dart';
import 'auth_provider.dart';

class NotificationsProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final ApiService? _apiService;
  final List<AppNotification> _notifications = [];
  bool _isLoading = false;
  NotificationsWebSocketService? _wsService;
  BuildContext? _context;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => unreadNotifications.length;

  bool get isLoading => _isLoading;

  NotificationsProvider([this._apiService]) {
    _loadNotifications();
    // Don't initialize WebSocket in constructor - wait for explicit connect call
    // This ensures user is authenticated and context is available
  }

  /// Pull the server-side notification feed (same rows the web bell shows)
  /// and merge it with locally generated notifications.
  Future<void> syncFromServer() async {
    if (_apiService == null) return;
    try {
      final response = await _apiService!.getNotifications();
      final rows = (response.data as List?) ?? [];
      final serverNotifications = rows
          .map((row) =>
              AppNotification.fromServer(Map<String, dynamic>.from(row as Map)))
          .toList();

      // Server is the source of truth for its own rows; keep local-only ones.
      _notifications.removeWhere((n) => n.id.startsWith('srv_'));
      _notifications.addAll(serverNotifications);
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _saveNotifications();
      notifyListeners();
    } catch (e) {
      print('❌ Error syncing notifications from server: $e');
    }
  }

  Future<void> _initializeWebSocket() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      print('🔌 Initializing notifications WebSocket...');
      print('🔌 Token exists: ${token != null && token.isNotEmpty}');
      
      // Only connect if user is authenticated
      if (token != null && token.isNotEmpty) {
        // Disconnect existing connection if any
        if (_wsService != null) {
          print('🔌 Disconnecting existing WebSocket connection');
          _wsService?.disconnect();
        }
        
        _wsService = NotificationsWebSocketService(prefs);
        _wsService!.connect((order) async {
          print('📥 Received new_order event in notifications provider');
          print('📥 Order code: ${order.code}, Collector ID: ${order.collector?.id}');
          
          // Handle new order notification
          // Don't notify if the current user created the order themselves
          // We need to check the current user from AuthProvider
          if (_context != null) {
            try {
              final authProvider = Provider.of<AuthProvider>(_context!, listen: false);
              final currentUserId = authProvider.user?.id;
              
              print('📥 Current user ID: $currentUserId');
              
              // Skip notification if user created the order themselves
              if (currentUserId != null && order.collector?.id == currentUserId) {
                print('📱 Skipping notification for order created by current user');
                return;
              }
            } catch (e) {
              print('❌ Error checking current user: $e');
              // Continue with notification if we can't check
            }
          } else {
            print('⚠️ No context available to check current user, showing notification anyway');
          }
          
          print('📱 Showing notification for order: ${order.code}');
          // Show notification for orders created by others
          await notifyOrderCreated(
            orderCode: order.code,
            restaurantName: order.restaurant.name,
            orderId: order.id.toString(),
          );
        }, onNotification: (payload) async {
          // Personal server notification (payment_due, payment_received,
          // order_joined, order_status, ...) → bell list + system tray.
          try {
            await addNotification(AppNotification.fromServer(payload));
          } catch (e) {
            print('❌ Error handling server notification: $e');
          }
        });
        print('✅ Notifications WebSocket service initialized');
      } else {
        print('⚠️ Cannot initialize WebSocket: No access token');
      }
    } catch (e) {
      print('❌ Error initializing notifications WebSocket: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  void connectWebSocket([BuildContext? context]) {
    _context = context;
    _initializeWebSocket();
    // Refresh the bell from the server whenever we (re)connect.
    syncFromServer();
  }

  void disconnectWebSocket() {
    _wsService?.disconnect();
    _wsService = null;
  }

  Future<void> loadNotifications() async {
    await _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('notifications') ?? [];
      _notifications.clear();
      _notifications.addAll(
        notificationsJson.map((raw) {
          try {
            if (raw.startsWith('{')) {
              return AppNotification.fromJson(
                  Map<String, dynamic>.from(jsonDecode(raw) as Map));
            }
            // Legacy pipe-separated format (pre-JSON persistence)
            final parts = raw.split('|');
            if (parts.length >= 5) {
              return AppNotification(
                id: parts[0],
                title: parts[1],
                body: parts[2],
                type: NotificationType.values.firstWhere(
                  (e) => e.toString().split('.').last == parts[3],
                  orElse: () => NotificationType.info,
                ),
                createdAt: DateTime.parse(parts[4]),
                isRead: parts.length > 5 ? parts[5] == 'true' : false,
              );
            }
          } catch (e) {
            print('Error parsing notification: $e');
          }
          return null;
        }).whereType<AppNotification>(),
      );
      
      // Sort by creation date (newest first)
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson =
          _notifications.map((n) => jsonEncode(n.toJson())).toList();
      await prefs.setStringList('notifications', notificationsJson);
    } catch (e) {
      print('Error saving notifications: $e');
    }
  }

  Future<void> addNotification(AppNotification notification) async {
    // Check if notification already exists (avoid duplicates)
    if (_notifications.any((n) => n.id == notification.id)) {
      return;
    }

    _notifications.insert(0, notification);
    await _saveNotifications();
    
    // Show local notification
    await _notificationService.showNotification(notification);
    
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final notification = _notifications[index];
      _notifications[index] = notification.copyWith(isRead: true);
      await _saveNotifications();
      notifyListeners();

      // Propagate to the server so the web bell stays in sync.
      final serverId = notification.data?['server_id'];
      if (serverId is int && _apiService != null) {
        try {
          await _apiService!.markNotificationRead(serverId);
        } catch (e) {
          print('❌ Error marking server notification read: $e');
        }
      }
    }
  }

  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    await _saveNotifications();
    notifyListeners();

    if (_apiService != null) {
      try {
        await _apiService!.markAllNotificationsRead();
      } catch (e) {
        print('❌ Error marking all server notifications read: $e');
      }
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> clearAllNotifications() async {
    _notifications.clear();
    await _saveNotifications();
    notifyListeners();
  }

  // Helper methods for common notification types
  Future<void> notifyOrderCreated({
    required String orderCode,
    required String restaurantName,
    String? orderId,
  }) async {
    final notification = _notificationService.createOrderCreatedNotification(
      orderCode: orderCode,
      restaurantName: restaurantName,
      orderId: orderId,
    );
    await addNotification(notification);
  }

  Future<void> notifyOrderUpdated({
    required String orderCode,
    required String status,
    String? orderId,
  }) async {
    final notification = _notificationService.createOrderUpdatedNotification(
      orderCode: orderCode,
      status: status,
      orderId: orderId,
    );
    await addNotification(notification);
  }

  Future<void> notifyItemAdded({
    required String orderCode,
    required String itemName,
    required String userName,
    String? orderId,
  }) async {
    final notification = _notificationService.createItemAddedNotification(
      orderCode: orderCode,
      itemName: itemName,
      userName: userName,
      orderId: orderId,
    );
    await addNotification(notification);
  }

  Future<void> notifyPayment({
    required String orderCode,
    required String userName,
    required double amount,
    required bool isPaid,
    String? orderId,
  }) async {
    final notification = _notificationService.createPaymentNotification(
      orderCode: orderCode,
      userName: userName,
      amount: amount,
      isPaid: isPaid,
      orderId: orderId,
    );
    await addNotification(notification);
  }

  Future<void> scheduleCutoffReminder({
    required String orderCode,
    required DateTime cutoffTime,
    String? orderId,
  }) async {
    // Schedule notification 15 minutes before cutoff
    final reminderTime = cutoffTime.subtract(const Duration(minutes: 15));
    if (reminderTime.isAfter(DateTime.now())) {
      final notification = _notificationService.createCutoffTimeReminder(
        orderCode: orderCode,
        cutoffTime: cutoffTime,
        orderId: orderId,
      );
      await _notificationService.scheduleNotification(notification, reminderTime);
      
      // Also add to in-app notifications
      await addNotification(notification);
    }
  }
}

